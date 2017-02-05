
import Base: eltype

keytype(::Type{Any}) = Any
valuetype(::Type{Any}) = Any

keytype{K,V}(::Type{Associative{K,V}}) = K
valuetype{K,V}(::Type{Associative{K,V}}) = V

keytype{T<:Associative}(::Type{T}) = keytype(supertype(T))
valuetype{T<:Associative}(::Type{T}) = valuetype(supertype(T))

function arraytype_dims(elt, dimst)
    tuplen = StaticTypeAnalysis.length(dimst)
    if isnull(tuplen)
        return Array{elt}
    else
        return Array{elt, get(tuplen)}
    end
end

function evaltype(ex::Symbol)
    ret = Any
    if isdefined(Base, ex)
        ret = getfield(Base, ex)
    end
    return isa(ret, Type) ? ret : Any
end
evaltype(::Any) = Any

# ex should be a type. figure out what it is
function parsetype(ex)
    ret = Any
    if isa(ex, Symbol)
        return evaltype(ex)
    elseif typeof(ex) <: Expr
        if isexpr(ex, :curly)
            if ex.args[1] == :Array
                elt = Any
                if length(ex.args) == 1
                    return Array
                elseif length(ex.args) >= 2
                    elt = evaltype(ex.args[2])
                    if length(ex.args) == 2
                        return Array{elt}
                    elseif typeof(ex.args[3]) <: Integer
                        return Array{elt, ex.args[3]}
                    else
                        return Array{elt}
                    end
                end
            elseif ex.args[1] == :Dict
                if length(ex.args) == 1
                    return Dict
                elseif length(ex.args) == 3
                    kt = parsetype(ex.args[2])
                    vt = parsetype(ex.args[3])
                    return Dict{kt, vt}
                end
            elseif ex.args[1] == :Vector
                if length(ex.args) != 2
                    return Vector
                else
                    vt = parsetype(ex.args[2])
                    return Vector{vt}
                end
            elseif ex.args[1] == :Complex
                if length(ex.args) != 2
                    return Complex
                else
                    vt = parsetype(ex.args[2])
                    return Complex{vt}
                end
            end
        end
    end
    return ret
end

function guesstype(ex, ctx::LintContext)
    t = typeof(ex)
    if t <: Number
        return t
    end
    if t <: AbstractString
        return t
    end
    if t == Symbol # check if we have seen it
        if ex == :nothing
            return Void
        end
        if ex == :(:)
            return Colon
        end
        # TODO: this should be a module function
        checkret = x -> begin
            if isa(x, Type)
                return x
            else
                tmp = x
                try
                    tmp = eval(x)
                end
                if isa(tmp, Type)
                    return tmp
                else
                    return x
                end
            end
        end
        stacktop = ctx.callstack[end]
        sym = ex
        for i in length(stacktop.localvars):-1:1
            if haskey(stacktop.localvars[i], sym)
                ret = stacktop.localvars[i][sym].typeactual
                return checkret(ret)
            end
        end
        for i in length(stacktop.localarguments):-1:1
            if haskey(stacktop.localarguments[i], sym)
                ret = stacktop.localarguments[i][sym].typeactual
                return checkret(ret)
            end
        end
        for i in length(ctx.callstack):-1:1
            if in(sym, ctx.callstack[i].types)
                return Type
            end
            if in(sym, ctx.callstack[i].functions)
                return Function
            end
            if in(sym, ctx.callstack[i].modules)
                return Module
            end
        end
        try
            if isdefined(Base, ex)
                val = getfield(Base, ex)
                if isa(val, Type)
                    return Type{val}
                else
                    return typeof(val)
                end
            end
        end
        return Any
    end

    if t == QuoteNode
        return typeof(ex.value)
    end

    if t != Expr
        return Any
    end

    if isexpr(ex, :tuple)
        ts = Any[]
        for a in ex.args
            push!(ts, guesstype(a, ctx))
        end
        return Tuple{ts...}
    end

    if isexpr(ex, :(::)) && length(ex.args) == 2
        return evaltype(ex.args[2])
    end

    if isexpr(ex, :block)
        return isempty(ex.args) ? Void : guesstype(ex.args[end], ctx)
    end

    if isexpr(ex, :return)
        tmp = guesstype(ex.args[1], ctx)
        return tmp
    end

    if isexpr(ex, :call)
        # TODO: deal with vararg (...) calls properly
        fn = ex.args[1]
        argtypes = map(x -> guesstype(x, ctx), ex.args[2:end])

        # check if it's a constructor for user-defined type, and figure
        # out what type
        # this is hackish because the return type is a Symbol, not a Type
        if fn == :new
            return Symbol(ctx.scope)
        end

        # another detection for constructor calling another constructor
        # A() = A(default)
        if Symbol(ctx.scope) == fn
            found = false
            for i = length(ctx.callstack):-1:1
                found = in(fn, ctx.callstack[i].types)
                if found
                    return fn
                end
            end
        end
        # A() = A{T}(default)
        if isexpr(fn, :curly) &&
                Symbol(ctx.scope) == fn.args[1]
            found = false
            for i = length(ctx.callstack):-1:1
                found = in(fn.args[1], ctx.callstack[i].types)
                if found
                    return fn.args[1]
                end
            end
        end

        # infer return types of Base functions
        if isa(fn, Symbol) && isdefined(Base, fn)
            inferred = try
                typejoin(Base.return_types(
                    getfield(Base, fn),
                    Tuple{(isa(t, Type) ? t : Any for t in argtypes)...})...)
            catch  # error might be thrown if generic function, try using inference
                if all(typ -> isa(typ, Type) && isleaftype(typ), argtypes)
                    Core.Inference.return_type(
                        getfield(Base, fn),
                        Tuple{argtypes...})
                else
                    Any
                end
            end
            if inferred ≠ Any
                return inferred
            end
        end

        # try special cases when Base.return_types can't give good answer
        if isexpr(fn, :curly)
            return parsetype(ex.args[1])
        end
    end

    if isexpr(ex, :macrocall)
        if ex.args[1] == Symbol("@sprintf") || isexpr(ex, :call) && in(ex.args[1], [
                    :replace, :string, :utf8, :utf16, :utf32, :repr, :normalize_string,
                    :join, :chop, :chomp, :lpad, :rpad, :strip, :lstrip, :rstrip,
                    :uppercase, :lowercase, :ucfirst, :lcfirst, :escape_string,
                    :unescape_string
                ])
            return AbstractString
        elseif ex.args[1] == Symbol("@compat")
            return guesstype(ex.args[2], ctx)
        end
    end

    if isexpr(ex, :(:))
        return Range
    end

    if isexpr(ex, :curly)
        return Type
    end

    if isexpr(ex, Symbol("'"))
        fst = guesstype(ex.args[1], ctx)
        return fst
    end

    if isexpr(ex, :ref) # it could be a ref a[b] or an array Int[1,2,3], Vector{Int}[]
        if isexpr(ex.args[1], :curly) # must be a datatype, right?
            elt = parsetype(ex.args[1])
            return Array{elt, 1}
        end

        if typeof(ex.args[1]) == Symbol
            what = registersymboluse(ex.args[1], ctx, false)
            if what == :Type
                elt = parsetype(ex.args[1])
                return Array{elt, 1}
            elseif what == :Any
                msg(ctx, :W543, ex.args[1], "Lint cannot determine if Type or not")
                return Any
            end
        end
        # not symbol, or symbol but it refers to a variable
        partyp = guesstype(ex.args[1], ctx)
        if typeof(partyp) == Symbol # we are in a context of a constructor of a new type, so it's difficult to figure out the content
            return Any
        elseif partyp <: UnitRange
            if length(ex.args) < 2
                msg(ctx, :E121, ex.args[1], "Lint does not understand the expression")
                return Any
            end
            ktypeactual = guesstype(ex.args[2], ctx)
            if ktypeactual <: Integer
                return StaticTypeAnalysis.eltype(partyp)
            elseif isexpr(ex.args[2], :(:)) # range too
                return partyp
            elseif isexpr(ex.args[2], :call) && ex.args[2].args[1] == :Colon
                return partyp
            else
                return Any
            end
        elseif partyp <: AbstractArray
            eletyp = StaticTypeAnalysis.eltype(partyp)
            try
                nd = ndims(partyp) # This may throw if we couldn't infer the dimension
                tmpdim = nd - (length(ex.args)-1)
                if tmpdim < 0
                    if nd == 0 && ex.args[2] == 1 # ok to do A[1] for a 0-dimensional array
                        return eletyp
                    else
                        msg(ctx, :E436, ex, "more indices than dimensions")
                        return Any
                    end
                end

                for i in 2:length(ex.args)
                    if ex.args[i] == :(:) || isexpr(ex.args[i], :call) &&
                            ex.args[i].args[1] == :Colon
                        tmpdim += 1
                    end
                end
                if tmpdim != 0
                    return Array{eletyp, tmpdim} # is this strictly right?
                else
                    return eletyp
                end
            end
            return Any
        elseif partyp <: Associative
            ktypeexpect = keytype(partyp)
            vtypeexpect = valuetype(partyp)
            if length(ex.args) < 2
                msg(ctx, :E121, ex.args[1], "Lint does not understand the expression")
                return Any
            end
            ktypeactual = guesstype(ex.args[2], ctx)
            if ktypeactual != Any && !(ktypeactual <: ktypeexpect)
                msg(ctx, :E518, ex.args[2], "key type expects $(ktypeexpect), " *
                    "provided $(ktypeactual)")
            end
            return vtypeexpect
        elseif partyp <: AbstractString
            if length(ex.args) < 2
                msg(ctx, :E121, ex.args[1], "Lint does not understand the expression")
                return Any
            end
            ktypeactual = guesstype(ex.args[2], ctx)
            if ktypeactual != Any && !(ktypeactual <: Integer) && !(ktypeactual <: Range)
                msg(ctx, :E519, ex.args[2], "string[] expects Integer, provided $(ktypeactual)")
            end
            if ktypeactual <: Integer
                return Char
            end
            if ktypeactual <: Range
                return partyp
            end
        elseif partyp <: Tuple
            return StaticTypeAnalysis.eltype(partyp)
        elseif partyp != Any
            if ctx.versionreachable(VERSION) && !pragmaexists("$(partyp) is a container type", ctx)
                msg(ctx, :E521, ex.args[1], "apparent type $(partyp) is not a container type")
            end
        end
        return Any
    end

    if isexpr(ex, :(=>))
        t1 = guesstype(ex.args[1], ctx)
        t2 = guesstype(ex.args[2], ctx)
        return Pair{t1,t2}
    end

    if isexpr(ex, :comparison)
        return Bool
    end

    # simple if statement e.g. test ? 0 : 1
    if isexpr(ex, :if) && length(ex.args) == 3
        tt = guesstype(ex.args[2], ctx)
        ft = guesstype(ex.args[3], ctx)
        if tt == ft
            return tt
        else
            return Any
        end
    end

    if isexpr(ex, :(->))
        return Function
    end

    return Any
end
