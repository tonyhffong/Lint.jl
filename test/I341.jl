@testset "I341" begin
    @test messageset(lintstr("""
    f(; a=1) = a
    a = (:a, 1)
    f(; a)
    """)) == Set([:I341])

    @test messageset(lintstr("""
    f(; a=1) = a
    a = :b
    f(; a => 1)
    """)) == Set([:I341])

end
