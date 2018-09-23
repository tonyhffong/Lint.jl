using Base: isexported

"""
    stdlibobject(name::Symbol)

If `name` is an export of Base or Core, return `x` where `x` is
the object itself. Otherwise, return `nothing`.
"""
function stdlibobject(ex::Symbol)
    if isexported(Base, ex) && isdefined(Base, ex)
        getfield(Base, ex)
    elseif isexported(Core, ex) && isdefined(Core, ex)
        getfield(Core, ex)
    else
        nothing
    end
end

"""
    parsetype(ctx::LintContext, ex::Expr) :: Type

Obtain a supertype of the type represented by `ex`.
"""
function parsetype(ctx::LintContext, ex)
    obj = abstract_eval(ctx, ex)
    if !isnull(obj) && isa(get(obj), Type)
        get(obj)
    elseif isexpr(ex, :curly)
        obj = abstract_eval(ctx, ex.args[1])
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
    result = lookup(ctx, ex)
    if isnull(result)
        Any  # conservative guess
    else
        get(result).typeactual
    end
end

function guesstype(ex::Expr, ctx::LintContext)::Type
    ex = ExpressionUtils.expand_trivial_calls(ex)

    if isexpr(ex, :tuple)
        ts = Type[]
        for a in ex.args
            push!(ts, guesstype(a, ctx))
        end
        return Tuple{ts...}
    end

    if isexpr(ex, :(::)) && length(ex.args) == 2
        return parsetype(ctx, ex.args[2])
    end

    if isexpr(ex, :block)
        return isempty(ex.args) ? Nothing : guesstype(ex.args[end], ctx)
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

        # infer return types of Base functions
        obj = abstract_eval(ctx, fn)
        type_argtypes = [isa(t, Type) ? t : Any for t in argtypes]
        if !isnull(obj)
            inferred = StaticTypeAnalysis.infertype(get(obj), type_argtypes)
            if inferred ≠ Any
                return inferred
            end
        end
    end

    if isexpr(ex, :macrocall)
        if ex.args[1] == Symbol("@sprintf")
            return String
        elseif ex.args[1] == Symbol("@compat")
            return guesstype(ex.args[2], ctx)
        end
    end

    if isexpr(ex, :curly)
        return Type
    end

    if isexpr(ex, :ref) # it could be a ref a[b] or an array Int[1,2,3], Vector{Int}[]
        if isexpr(ex.args[1], :curly) # must be a datatype, right?
            elt = abstract_eval(ctx, ex.args[1])
            if !isnull(elt) && isa(get(elt), Type)
                return Vector{get(elt)}
            else
                return Vector
            end
        end

        if isa(ex.args[1], Symbol)
            what = registersymboluse(ex.args[1], ctx)
            if what <: Type
                elt = abstract_eval(ctx, ex.args[1])
                if !isnull(elt) && isa(get(elt), Type)
                    return Vector{get(elt)}
                else
                    return Vector
                end
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
            catch
                return Any
            end
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
            nothing
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
