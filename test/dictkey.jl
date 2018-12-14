@testset "Dictionaries" begin
    let s = """
Dict(:a=>1, :b=>2, :a=>3)
""",
        msgs = lintstr(s)
        @test msgs[1].code == :E334
    end

    let s = """
Dict{Symbol,Int}(:a=>1, :b=>"")
""",
        msgs = lintstr(s)
        @test msgs[1].code == :E532
    end

    let s = """
Dict{Symbol,Int}(:a=>1, "b"=>2)
""",
        msgs = lintstr(s)
        @test msgs[1].code == :E531
    end
end
