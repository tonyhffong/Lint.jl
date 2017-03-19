using Lint.ExpressionUtils

@testset "Expressions" begin
    @test expand_trivial_calls(:(1:2)) == :(colon(1, 2))
    @test expand_trivial_calls(:(A')) == :(ctranspose(A))
    @test expand_trivial_calls(:(A.')) == :(transpose(A))
end
