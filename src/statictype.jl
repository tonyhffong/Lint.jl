module StaticTypeAnalysis

macro lintpragma(ex); end

function __init__()
    global const EQ_METHOD_FALSE = which(==, Tuple{Void, Int})
end

"""
    StaticTypeAnalysis.canequal(S::Type, T::Type) :: Nullable{Bool}

Given types `S` and `T`, return `Nullable(false)` if it is not possible for
`s::S == t::T`. Return `Nullable(true)` if it is possible, and
`Nullable{Bool}()` if it cannot be determined.

``jldoctest
julia> StaticTypeAnalysis.canequal(Int, Float64)
Nullable(true)

julia> StaticTypeAnalysis.canequal(Int, String)
Nullable(false)
```
"""
function canequal(S::Type, T::Type)
    if S == Union{} || T == Union{}
        return Nullable(false)
    elseif typeintersect(S, T) ≠ Union{}
        # TODO: this is not fully correct; some types are not Union{} but still
        # not instantiated
        return Nullable{Bool}(true)
    elseif isleaftype(S) && isleaftype(T) &&
           EQ_METHOD_FALSE == which(==, Tuple{S, T})
        # == falls back to === here, but we saw earlier that the intersection
        # is empty
        return Nullable(false)
    elseif try zero(S) == zero(T) catch false end
        return Nullable{Bool}(true)
    else
        return Nullable{Bool}()
    end
end

"""
    StaticTypeAnalysis.isknownerror(f, argtypes)

Return `true` if it is known, without inference, that calling `f` with
signature `argtypes` will result in an error.

Consumers of this package are advised to use `infertype` and check the result
against `Union{}`, which covers more cases.
"""
isknownerror(f, argtypes) = false
function isknownerror(::typeof(Base.getindex), argtypes)
    if isempty(argtypes)
        true
    elseif argtypes[1] <: Associative
        if Base.length(argtypes) ≠ 2
            true
        else
            try
                K = keytype(argtypes[1])
                ce = canequal(K, argtypes[2])
                !isnull(ce) && !get(ce)
            catch
                false
            end
        end
    else
        false
    end
end

"""
    StaticTypeAnalysis.infertype(f, argtypes)

Given a function `f` and a list of types `argtypes`, use inference and other
static type checking techniques to figure out a type `S` such that the result
of applying `f` to `argtypes` is always of type `S`.
"""
infertype(f, argtypes) = infertype(f, (argtypes...))
function infertype(f, argtypes::Tuple)
    if isknownerror(f, argtypes)
        Union{}
    elseif f === Base.getindex && Base.length(argtypes) == 2 &&
           argtypes[1] == UnitRange && argtypes[2] <: UnitRange &&
           eltype(argtypes[2]) <: Integer
        # TODO: would be nice to get rid of this odd special case
        UnitRange
    else
        try
            typejoin(Base.return_types(f, Tuple{argtypes...})...)
        catch  # error might be thrown if generic function, try using inference
            if all(isleaftype, argtypes)
                Core.Inference.return_type(f, Tuple{argtypes...})
            else
                Any
            end
        end
    end
end

"""
    StaticTypeAnalysis.getindexable(T::Type)

Return `true` if all objects of type `T` support `getindex`, and the `getindex`
operation on numbers is consistent with iteration order.

Note that, in particular, this is not true for `String` and `Dict`.
"""
getindexable{T<:Union{Tuple,Pair,Array,Number}}(::Type{T}) = true
getindexable(::Type) = false

"""
    StaticTypeAnalysis.length(T::Type) :: Nullable{Int}

If it can be determined that all objects of type `T` have length `n`, then
return `Nullable(n)`. Otherwise, return `Nullable{Int}()`.
"""
length(::Type{Union{}}) = Nullable(0)
length(::Type) = Nullable{Int}()
length{T<:Pair}(::Type{T}) = Nullable(2)

if VERSION < v"0.6.0-dev.2123" # where syntax introduced by julia PR #18457
    length{T<:Tuple}(::Type{T}) = if Core.Inference.isvatuple(T)
        Nullable{Int}()
    else
        Nullable{Int}(Base.length(T.types))
    end
else
    include_string("""
    length(::Type{T}) where T <: NTuple{N, Any} where N = Nullable{Int}(N)
    """)
end

"""
    StaticTypeAnalysis.eltype(T::Type)

Return `S` as specific as possible such that all objects of type `T` have
element type `S`.
"""
eltype(::Type{Union{}}) = Union{}
eltype(T::Type) = Base.eltype(T)

_getindex_nth{n}(xs::Any, ::Type{Val{n}}) = xs[n]
_typeof_nth_getindex{T}(::Type{T}, n::Integer) =
    infertype(_getindex_nth, Any[T, Type{Val{Int(n)}}])

"""
    StaticTypeAnalysis.typeof_nth(T::Type)

Return `S` as specific as possible such that all objects of type `T`, when
iterated over, have `n`th element type `S`.
"""
typeof_nth(T::Type, n::Integer) =
    if getindexable(T)
        typeintersect(eltype(T), _typeof_nth_getindex(T, n))
    else
        eltype(T)
    end
typeof_nth{K,V}(::Type{Pair{K,V}}, n::Integer) =
    n == 1 ? K : n == 2 ? V : Union{}
typeof_nth(::Type{Union{}}, ::Integer) = Union{}

end
