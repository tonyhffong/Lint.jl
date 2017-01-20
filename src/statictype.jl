module StaticTypeAnalysis

"""
    StaticTypeAnalysis.length(T::Type)

If it can be determined that all objects of type `T` have length `n`, then
return `Nullable(n)`. Otherwise, return `Nullable{Int}()`.
"""
length(::Type{Union{}}) = Nullable(0)
length(::Type) = Nullable{Int}()
length{T<:Pair}(::Type{T}) = 2
if VERSION < v"0.6-"
    length{T<:Tuple}(::Type{T}) = Nullable{Int}(Base.length(T.parameters))
else
    include_string("""
    length(::Type{T}) where T <: NTuple{N, Any} where N = Nullable{Int}(N)
    """)
end

end
