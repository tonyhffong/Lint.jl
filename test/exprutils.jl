using Lint.ExpressionUtils

@testset "Expressions" begin
    @test expand_trivial_calls(:(A')) == :(ctranspose(A))
    @test expand_trivial_calls(:([(1, 2, 3), (4, 5, 6)])) == :(Base.vect((1, 2, 3), (4, 5, 6)))
end
