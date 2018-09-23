using Lint.ExpressionUtils

@testset "Expressions" begin
    @test expand_trivial_calls(:(A')) == :(ctranspose(A))
end
