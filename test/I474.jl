@testset "I474" begin
    @test isempty(messageset(lintstr("""
    function f(x)
        d = Dict{Symbol,Int}(:a=>1, :b=>2)
        for i in d
        end
        return x
    end
    """)))

    @test messageset(lintstr("""
    function f(x)
        d = Dict{Symbol,Int}(:a=>1, :b=>2)
        for (k,) in d
        end
        return x
    end
    """)) == Set([:I474])

    @test isempty(messageset(lintstr("""
    function f(a::Array{Int,1})
        for i in enumerate(a)
            println(i)
        end
    end
    """)))

    @test messageset(lintstr("""
    function f(x)
        d = [(1,2,3), (4,5,6)]
        for (i, j) in d
        end
        return x
    end
    """)) == Set([:I474])
end
