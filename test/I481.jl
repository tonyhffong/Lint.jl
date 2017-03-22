@testset "I481" begin
    @test isempty(lintstr("""
    s = Symbol("abc")
    """))

    @test Set([:I481]) ⊆ messageset(lintstr("""
    s = symbol("end")
    """))
end
