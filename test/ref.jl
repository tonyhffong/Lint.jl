@testset "I473" begin
    s = """
    r = [3,2,1]
    r[r]
    """
    msgs = lintstr(s)
    @test messageset(msgs) == Set([:I473])
    @test occursin(msgs[1].message, "value at position #1 is the referenced r")
    @test occursin(msgs[1].message, "OK if it represents permutations")
end

@testset "E434" begin
    msgs = lintstr("""
    r = [3,2,1]
    r[1;r]
    """)
    @test messageset(msgs) == Set([:E434])
    @test occursin(msgs[1].message, "value at position #2 is the referenced r. Possible typo?")
end
