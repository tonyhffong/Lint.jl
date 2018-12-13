@testset "Dictionary keys" begin
    s = """
Dict(:a=>1, :b=>2, :a=>3)
"""
    msgs = lintstr(s)
    @test msgs[1].code == :E334

    s = """
Dict{Symbol,Int}(:a=>1, :b=>"")
"""
    msgs = lintstr(s)
    @test msgs[1].code == :E532

    s = """
Dict{Symbol,Int}(:a=>1, "b"=>2)
"""
    msgs = lintstr(s)
    @test msgs[1].code == :E531
end
