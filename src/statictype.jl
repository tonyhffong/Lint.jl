module StaticTypeAnalysis

macro lintpragma(ex); end

EQ_METHOD_FALSE = which(==, Tuple{Nothing, Int})
#CONSTRUCTOR_FALLBACK = which(Nothing, Tuple{Nothing})

"""
    StaticTypeAnalysis.canequal(S::Type, T::Type) :: Union{Bool, Nothing}

Given types `S` and `T`, return `false` if it is not possible for
`s::S == t::T`. Return `true` if it is possible, and
`nothing` if it cannot be determined.

```jldoctest
julia> StaticTypeAnalysis.canequal(Int, Float64)
true

julia> StaticTypeAnalysis.canequal(Int, String)
false
```
"""
function canequal(S::Type, T::Type)
    if S == Union{} || T == Union{}
        false
    elseif typeintersect(S, T) ≠ Union{}
        # TODO: this is not fully correct; some types are not Union{} but still
        # not instantiated
        true
    elseif isconcretetype(S) && isconcretetype(T) &&
           EQ_METHOD_FALSE == which(==, Tuple{S, T})
        # == falls back to === here, but we saw earlier that the intersection
        # is empty
        false
    else
        try zero(S) == zero(T)
            true
        catch
            nothing
        end
    end
end

"""
    StaticTypeAnalysis.isknownerror(f, argtypes)

Return `true` if it is known, without inference, that calling `f` with
signature `argtypes` will result in an error.

Consumers of this package are advised to use `infertype` and check the result
against `Union{}`, which covers more cases.
"""
isknownerror(_f, _argtypes) = false
function isknownerror(::typeof(Base.getindex), argtypes::Tuple)
    # correctly forward arguments from `infertype` below
    isknownerror(typeof(Base.getindex), argtypes[1])
end
function isknownerror(::typeof(Base.getindex), argtypes)
    if isempty(argtypes)
        true
    elseif argtypes[1] <: AbstractDict
        if Base.length(argtypes) ≠ 2
            true
        else
            try
                K = keytype(argtypes[1])
                ce = canequal(K, argtypes[2])
                ce !== nothing && !ce
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
infertype(f, argtypes...) = infertype(f, argtypes)
function infertype(f, argtypes::Tuple)
    if isknownerror(f, argtypes)
        Union{}
    elseif f === Base.getindex && Base.length(argtypes) == 2 &&
           argtypes[1] == UnitRange && argtypes[2] <: UnitRange &&
           eltype(argtypes[2]) <: Integer
        # TODO: would be nice to get rid of this odd special case
        UnitRange
    # elseif isa(f, Type) && Base.length(argtypes) == 1 &&
    #        isconcretetype(argtypes[1]) &&
    #        which(f, Tuple{argtypes[1]}) === CONSTRUCTOR_FALLBACK
    #     # we can infer better code for the constructor `convert` fallback by
    #     # inferring the convert itself
    #     Core.Inference.return_type(convert, Tuple{Type{f}, argtypes[1]})
    else
        try
            typejoin(Base.return_types(f, Tuple{argtypes...})...)
        catch  # error might be thrown if generic function, try using inference
            if all(isconcretetype, argtypes)
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
getindexable(::Type{T}) where {T <: Union{Tuple,Pair,Array,Number}} = true
getindexable(::Type) = false

"""
    StaticTypeAnalysis.length(T::Type) :: Union{Int, Nothing}

If it can be determined that all objects of type `T` have length `n`, then
return `n`. Otherwise, return `nothing`.
"""
length(::Type{Union{}}) = 0
length(::Type) = nothing
length(::Type{T}) where {T <: Pair} = 2

# if VERSION < v"0.6.0-dev.2123" # where syntax introduced by julia PR #18457
#     length(::Type{T}) where {T <: Tuple} = if !isa(T, DataType) || Core.Inference.isvatuple(T)
#         nothing
#     else
#         Base.length(T.types)
#     end
# else
#     include_string("""
length(::Type{T}) where T <: NTuple{N, Any} where N = N
#     """)
# end

"""
    StaticTypeAnalysis.eltype(T::Type)

Return `S` as specific as possible such that all objects of type `T` have
element type `S`.
"""
eltype(::Type{Union{}}) = Union{}
eltype(T::Type) = Base.eltype(T)

_getindex_nth(xs::Any, ::Type{Val{n}}) where {n} = xs[n]
_typeof_nth_getindex(::Type{T}, n::Integer) where {T} =
    infertype(_getindex_nth, Any[T, Type{Val{Int(n)}}])

"""
    StaticTypeAnalysis.typeof_nth(T::Type)

Return `S` as specific as possible such that all objects of type `T`, when
iterated over, have `n`th element type `S`.
"""
typeof_nth(T::Type, n::Integer) =
    if getindexable(T) && 0 < Base.length(T.types)
        if n ≤ Base.length(T.types)
            typeintersect(eltype(T), T.types[n])
        else
            Union{}
        end
    else
        eltype(T)
    end
typeof_nth(::Type{Pair{K,V}}, n::Integer) where {K, V} =
    n == 1 ? K : n == 2 ? V : Union{}
typeof_nth(::Type{Union{}}, ::Integer) = Union{}
typeof_nth(::Type{Tuple{Vararg{Any}}}, ::Integer) = Any

end
