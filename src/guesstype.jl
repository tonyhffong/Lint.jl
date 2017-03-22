using Base: isexported

"""
    stdlibobject(name::Symbol)

If `name` is an export of Base or Core, return `Nullable{Any}(x)` where `x` is
the object itself. Otherwise, return `Nullable{Any}()`.
"""
function stdlibobject(ex::Symbol)
    if isexported(Base, ex) && isdefined(Base, ex)
        Nullable{Any}(getfield(Base, ex))
    elseif isexported(Core, ex) && isdefined(Core, ex)
        Nullable{Any}(getfield(Core, ex))
    else
        Nullable{Any}()
    end
end

"""
    stdlibobject(ex::Expr)

If the given expression is curly, and each component of the curly is a standard
library object, construct the object `x` as would have been done in the program
itself, and return `Nullable{Any}(x)`.

Otherwise, if the given expression is `foo.bar`, and `foo` is a standard
library object with attribute `bar`, then construct `foo.bar` as would be done
in the program itself and return it.

Otherwise, return `Nullable{Any}()`.
"""
function stdlibobject(ex::Expr)
    if isexpr(ex, :curly)
        objs = stdlibobject.(ex.args)
        if all(!isnull, objs)
            try
                Nullable{Any}(Core.apply_type(get.(objs)...))
            catch
                Nullable{Any}()
            end
        else
            Nullable{Any}()
        end
    elseif isexpr(ex, :(.))
        head = ex.args[1]
        tail = ex.args[2].value
        obj = stdlibobject(head)
        if !isnull(obj)
            try
                Nullable{Any}(getfield(get(obj), tail))
            catch
                Nullable{Any}()
            end
        else
            Nullable{Any}()
        end
    else
        Nullable{Any}()
    end
end

"""
    stdlibobject(ex)

Return the literal embedded within a `Nullable{Any}`.
"""
stdlibobject(ex) = lexicalvalue(ex)

"""
    parsetype(ex::Expr)

Obtain a supertype of the type represented by `ex`.
"""
function parsetype(ex)
    obj = stdlibobject(ex)
    if !isnull(obj) && isa(get(obj), Type)
        get(obj)
    elseif isexpr(ex, :curly)
        obj = stdlibobject(ex.args[1])
        if !isnull(obj) && isa(get(obj), Type) && get(obj) !== Union
            get(obj)
        else
            Any
        end
    else
        Any
    end
end

function guesstype(ex::Symbol, ctx::LintContext)
    stacktop = ctx.callstack[end]
    sym = ex
    for i in length(stacktop.localvars):-1:1
        if haskey(stacktop.localvars[i], sym)
            ret = stacktop.localvars[i][sym].typeactual
            return ret
        end
    end
    for i in length(stacktop.localarguments):-1:1
        if haskey(stacktop.localarguments[i], sym)
            ret = stacktop.localarguments[i][sym].typeactual
            return ret
        end
    end
    for i in length(ctx.callstack):-1:1
        if sym in ctx.callstack[i].types
            return Type
        end
        if sym in ctx.callstack[i].functions
            return Function
        end
        if sym in ctx.callstack[i].modules
            return Module
        end
    end
    val = stdlibobject(ex)
    if !isnull(val)
        if isa(get(val), Type)
            return Type{get(val)}
        else
            return typeof(get(val))
        end
    end
    return Any
end

function guesstype(ex::Expr, ctx::LintContext)
    ex = ExpressionUtils.expand_trivial_calls(ex)

    if isexpr(ex, :tuple)
        ts = Type[]
        for a in ex.args
            push!(ts, guesstype(a, ctx))
        end
        return Tuple{ts...}
    end

    if isexpr(ex, :(::)) && length(ex.args) == 2
        return parsetype(ex.args[2])
    end

    if isexpr(ex, :block)
        return isempty(ex.args) ? Void : guesstype(ex.args[end], ctx)
    end

    if isexpr(ex, :return)
        tmp = guesstype(ex.args[1], ctx)
        return tmp
    end

    if isexpr(ex, :call)
        fn = ex.args[1]
        if any(x -> isexpr(x, :kw) || isexpr(x, :(...)), ex.args[2:end])
            # TODO: smarter way to deal with kw/vararg
            return Any
        end
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
        obj = stdlibobject(fn)
        type_argtypes = [isa(t, Type) ? t : Any for t in argtypes]
        if !isnull(obj)
            inferred = StaticTypeAnalysis.infertype(get(obj), type_argtypes)
            if inferred ≠ Any
                return inferred
            end
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

    if isexpr(ex, :curly)
        return Type
    end

    if isexpr(ex, :ref) # it could be a ref a[b] or an array Int[1,2,3], Vector{Int}[]
        if isexpr(ex.args[1], :curly) # must be a datatype, right?
            elt = stdlibobject(ex.args[1])
            if !isnull(elt) && isa(get(elt), Type)
                return Vector{get(elt)}
            else
                return Vector
            end
        end

        if isa(ex.args[1], Symbol)
            what = registersymboluse(ex.args[1], ctx, false)
            if what == :Type
                elt = stdlibobject(ex.args[1])
                if !isnull(elt) && isa(get(elt), Type)
                    return Vector{get(elt)}
                else
                    return Vector
                end
            elseif what == :Any
                msg(ctx, :W543, ex.args[1], "Lint cannot determine if Type or not")
                return Any
            end
        end
        # not symbol, or symbol but it refers to a variable
        partyp = guesstype(ex.args[1], ctx)
        if isa(partyp, Symbol)
            # we are in a context of a constructor of a new type, so it's
            # difficult to figure out the content
            return Any
        elseif partyp <: AbstractArray && !(partyp <: Range)
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
        else
            argtypes = [guesstype(x, ctx) for x in ex.args]
            type_argtypes = [isa(t, Type) ? t : Any for t in argtypes]
            inferred = StaticTypeAnalysis.infertype(getindex, type_argtypes)
            if ctx.versionreachable(VERSION) && inferred == Union{}
                indtypes = if length(type_argtypes) == 1
                    "no indices"
                else
                    string("index types ", join(type_argtypes[2:end], ", "))
                end
                msg(ctx, :E522, ex,
                    string("indexing $(type_argtypes[1]) with ",
                           indtypes,
                           " is not supported"))
            end
            return inferred
        end
    end

    if isexpr(ex, :comparison)
        return Bool
    end

    # simple if statement e.g. test ? 0 : 1
    if isexpr(ex, :if) && 2 ≤ length(ex.args) ≤ 3
        tt = guesstype(ex.args[2], ctx)
        ft = if length(ex.args) == 3
            guesstype(ex.args[3], ctx)
        else
            Void
        end
        if tt == ft
            # we need this case because tt and ft might be symbols
            return tt
        elseif isa(tt, Type) && isa(ft, Type)
            return Union{tt, ft}
        else
            return Any
        end
    end

    if isexpr(ex, :(->))
        return Function
    end

    return Any
end

guesstype(ex, ctx::LintContext) = lexicaltypeof(ex)
