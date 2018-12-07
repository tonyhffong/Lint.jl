@testset "W361" begin
    s = """
    module Test361
    export foobar
    end
    """
    msgs = lintstr(s)
    @test msgs[1].code == :W361
    @test occursin(msgs[1].message, "exporting undefined symbol")
end
