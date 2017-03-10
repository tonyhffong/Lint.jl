module StaticTypeAnalysis

"""
    StaticTypeAnalysis.length(T::Type)

If it can be determined that all objects of type `T` have length `n`, then
return `Nullable(n)`. Otherwise, return `Nullable{Int}()`.
"""
length(::Type{Union{}}) = Nullable(0)
length(::Type) = Nullable{Int}()
length{T<:Pair}(::Type{T}) = 2
if VERSION < v"0.6.0-dev.2123" # where syntax introduced by julia PR #18457
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

end
