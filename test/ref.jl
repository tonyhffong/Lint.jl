@testset "I473" begin
    s = """
    r = [3,2,1]
    r[r]
    """
    msgs = lintstr(s)
    @test messageset(msgs) == Set([:I473])
    @test occursin("value at position #1 is the referenced r", msgs[1].message)
    @test occursin("OK if it represents permutations", msgs[1].message)
end

@testset "E434" begin
    msgs = lintstr("""
    r = [3,2,1]
    r[1;r]
    """)
    @test messageset(msgs) == Set([:E434])
    @test occursin("value at position #2 is the referenced r. Possible typo?", msgs[1].message)
end
