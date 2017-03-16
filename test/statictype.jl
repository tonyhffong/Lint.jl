using Lint: StaticTypeAnalysis

@testset "Static Type" begin

@test StaticTypeAnalysis.eltype(Tuple{Int,Int}) == Int
@test StaticTypeAnalysis.eltype(Tuple{Int,String}) == Any
@test StaticTypeAnalysis.eltype(Tuple{}) == Union{}
@test StaticTypeAnalysis.eltype(Tuple) == Any
@test StaticTypeAnalysis.eltype(Vector{Int}) == Int
@test StaticTypeAnalysis.eltype(Array{Int}) == Int

@test isnull(StaticTypeAnalysis.length(Tuple))
@test isnull(StaticTypeAnalysis.length(Array))
@test isnull(StaticTypeAnalysis.length(Vector{Int}))
@test isnull(StaticTypeAnalysis.length(Array{Int}))
@test get(StaticTypeAnalysis.length(Pair)) == 2
@test get(StaticTypeAnalysis.length(Tuple{Int,String})) == 2
@test get(StaticTypeAnalysis.length(NTuple{10, Integer})) == 10

@test StaticTypeAnalysis.typeof_nth(Tuple{Int,String}, 1) == Int
@test StaticTypeAnalysis.typeof_nth(Tuple{Int,String}, 2) == String
@test StaticTypeAnalysis.typeof_nth(Pair{Int,String}, 2) == String
@test StaticTypeAnalysis.typeof_nth(Pair{Int,String}, 1) == Int
@test StaticTypeAnalysis.typeof_nth(Vector{Int}, 1) == Int
@test StaticTypeAnalysis.typeof_nth(Tuple, 1) == Any
@test StaticTypeAnalysis.typeof_nth(Tuple{Int}, 2) == Union{}

end
