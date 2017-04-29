using Lint.RequiredKeywordArguments
using Base.Test

@testset "Required Arguments" begin
    foo1(; @required(bar)) = bar
    @test foo1(bar=42) == 42
    @test_throws ArgumentError foo1()

    foo2(; @required(bar::Integer)) = bar
    @test foo2(bar=42) == 42
    @test_throws TypeError foo2(bar="x")
    @test_throws ArgumentError foo2()
end
