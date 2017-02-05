module StaticTypeAnalysis

macro lintpragma(ex); end

"""
    StaticTypeAnalysis.infertype(f, argtypes)

Given a function `f` and a `Tuple` of types `argtypes`, use inference to figure
out a type `S` such that the result of applying `f` to `argtypes` is always of
type `S`.
"""
function infertype(f, argtypes)
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

"""
    StaticTypeAnalysis.getindexable(T::Type)

Return `true` if all objects of type `T` support `getindex`, and the `getindex`
operation on numbers is consistent with iteration order.

Note that, in particular, this is not true for `String` and `Dict`.
"""
getindexable{T<:Union{Tuple,Pair,Array,Number}}(::Type{T}) = true
getindexable(::Type) = false

"""
    StaticTypeAnalysis.length(T::Type)

If it can be determined that all objects of type `T` have length `n`, then
return `Nullable(n)`. Otherwise, return `Nullable{Int}()`.
"""
length(::Type{Union{}}) = Nullable(0)
length(::Type) = Nullable{Int}()
length{T<:Pair}(::Type{T}) = Nullable(2)
if VERSION < v"0.6-"
    length{T<:Tuple}(::Type{T}) = Nullable{Int}(Base.length(T.parameters))
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
