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
    if obj !== nothing && isa(obj, Type)
        obj
    elseif isexpr(ex, :curly)
        obj = abstract_eval(ctx, ex.args[1])
        if obj !== nothing && isa(obj, Type) && obj !== Union
            obj
        else
            Any
        end
    else
        Any
    end
end

"""Returns true if ex is `:` or `Colon()`"""
function iscolon(ex)::Bool
    return ex == :(:) || ex == :(Colon())
end

function guesstype(ex::Symbol, ctx::LintContext)
    result = lookup(ctx, ex)
    if result ≡ nothing
        Any  # conservative guess
    else
        result.typeactual
    end
end

# Tag definitions
abstract type ExpressionTag end
struct TupleTag <: ExpressionTag end
struct ColonTag <: ExpressionTag end
struct BlockTag <: ExpressionTag end
struct ReturnTag <: ExpressionTag end
struct MacroCallTag <: ExpressionTag end
struct CallTag <: ExpressionTag end
struct RefTag <: ExpressionTag end
struct ComparisonTag <: ExpressionTag end
struct CurlyTag <: ExpressionTag end
struct TernaryIfTag <: ExpressionTag end
struct LambdaTag <: ExpressionTag end
struct AssignTag <: ExpressionTag end
struct DefaultTag <: ExpressionTag end

# condition → tag
# see devdocs/ast for a comprehensible table of expressions
# TODO(felipe): Use Match.jl
function get_tag_per_condition(ex::Expr)
    if isexpr(ex, :tuple)
        return TupleTag
    end
    if isexpr(ex, :(::)) && length(ex.args) == 2
        return ColonTag
    end
    if isexpr(ex, :block)
        return BlockTag
    end
    if isexpr(ex, :return)
        return ReturnTag
    end
    if isexpr(ex, :call)
        return CallTag
    end
    if isexpr(ex, :macrocall)
        return MacroCallTag
    end
    if isexpr(ex, :ref) # it could be a ref a[b] or an array Int[1,2,3], Vector{Int}[]
        return RefTag
    end
    if isexpr(ex, :comparison)
        return ComparisonTag
    end
    if isexpr(ex, :curly)
        return CurlyTag
    end
    # simple if statement e.g. test ? 0 : 1
    if isexpr(ex, :if) && 2 ≤ length(ex.args) ≤ 3
        return TernaryIfTag
    end

    if isexpr(ex, :(->))
        return LambdaTag
    end
    if isexpr(ex, :(=))
        return AssignTag
    end

    return DefaultTag
end

# Specializations for each type below
function guesstype(ex::Expr, ctx::LintContext, ::Type{TupleTag})::Type
    ts = Type[]
    for a in ex.args
        push!(ts, guesstype(a, ctx))
    end
    return Tuple{ts...}
end

function guesstype(ex::Expr, ctx::LintContext, ::Type{ColonTag})::Type
    parsetype(ctx, ex.args[2])
end

function guesstype(ex::Expr, ctx::LintContext, ::Type{BlockTag})::Type
    isempty(ex.args) ? Nothing : guesstype(ex.args[end], ctx)
end

function guesstype(ex::Expr, ctx::LintContext, ::Type{ReturnTag})::Type
    guesstype(ex.args[1], ctx)
end

function guesstype(ex::Expr, ctx::LintContext, ::Type{CallTag})::Type
    fn = ex.args[1]
    if any(x -> isexpr(x, :kw) || isexpr(x, :(...)), ex.args[2:end])
        # TODO: smarter way to deal with kw/vararg
        return Any
    end
    argtypes = map(x -> guesstype(x, ctx), ex.args[2:end])

    # infer return types of Base functions
    obj = abstract_eval(ctx, fn)
    type_argtypes = [isa(t, Type) ? t : Any for t in argtypes]
    if obj !== nothing
        if obj isa Type && obj <: Dict # obj is a Dict-like type
            # TODO felipel: make sure that returned Dict has proper parameter types (Dict{KeyType,ValueType})
            #               either from type or deduced from arguments
            return obj
        end
        inferred = StaticTypeAnalysis.infertype(obj, type_argtypes)
        if inferred ≠ Any
            return inferred
        end
    end
    return Any
end

function guesstype(ex::Expr, ctx::LintContext, ::Type{MacroCallTag})::Type
    if ex.args[1] == Symbol("@sprintf")
        return String
    elseif ex.args[1] == Symbol("@compat")
        return guesstype(ex.args[2], ctx)
    end
end

function guesstype(ex::Expr, ctx::LintContext, ::Type{RefTag})::Type
        if isexpr(ex.args[1], :curly) # must be a datatype, right?
            elt = abstract_eval(ctx, ex.args[1])
            if elt !== nothing && isa(elt, Type)
                return Vector{elt}
            else
                return Vector
            end
        end

        if isa(ex.args[1], Symbol)
            what = registersymboluse(ex.args[1], ctx)
            if what <: Type
                elt = abstract_eval(ctx, ex.args[1])
                if elt !== nothing && isa(elt, Type)
                    return Vector{elt}
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
        elseif partyp <: AbstractArray && !(partyp <: AbstractRange)
            eletyp = StaticTypeAnalysis.eltype(partyp)
            nd=0
            try
                nd = ndims(partyp) # This may throw if we couldn't infer the dimension
            catch
                return Any
            end
            dim_diff = nd - (length(ex.args)-1)
            if dim_diff < 0
                if nd == 0 && ex.args[2] == 1 # ok to do A[1] for a 0-dimensional array
                    return eletyp
                else
                    msg(ctx, :E436, ex, "more indices than dimensions")
                    return Any
                end
            end
            colon_arguments = filter(iscolon, ex.args[2:end])
            dim_diff+=length(colon_arguments)

            if dim_diff != 0
                return Array{eletyp, dim_diff} # is this strictly right?
            else
                return eletyp
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

function guesstype(ex::Expr, ctx::LintContext, ::Type{ComparisonTag})::Type
    Bool
end

function guesstype(ex::Expr, ctx::LintContext, ::Type{CurlyTag})::Type
    Type
end

function guesstype(ex::Expr, ctx::LintContext, ::Type{TernaryIfTag})::Type
    tt = guesstype(ex.args[2], ctx)
    ft = if length(ex.args) == 3
        guesstype(ex.args[3], ctx)
    else
        Nothing
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

function guesstype(ex::Expr, ctx::LintContext, ::Type{LambdaTag})::Type
    Function
end

function guesstype(ex::Expr, ctx::LintContext, ::Type{DefaultTag})::Type
    Any
end

function guesstype(ex::Expr, ctx::LintContext, ::Type{AssignTag})::Type
    return guesstype(ex.args[2], ctx)
end

# `guesstype` dispatcher (resolves the tag)
function guesstype(ex::Expr, ctx::LintContext)::Type
    ex = ExpressionUtils.expand_trivial_calls(ex)
    return guesstype(ex, ctx, get_tag_per_condition(ex))
end

guesstype(ex, ctx::LintContext) = lexicaltypeof(ex)
