@testset "E522" begin
    msgs = lintstr("""
    s = I
    println(s[1])
    """)
    
    @test messageset(msgs) == Set([:E522])
    @test msgs[1].variable == "s[1]"
    @test contains(msgs[1].message, "indexing UniformScaling")
    @test contains(msgs[1].message, "with index types $Int is not supported")

    # dicts
    @test messageset(lintstr("""
    s = keys(Dict(1 => 2))
    println(s["foo"])
    """)) == Set([:E522])
    @test messageset(lintstr("""
    s = Dict(1 => 2)
    println(s["foo"])
    """)) == Set([:E522])
    @test isempty(messageset(lintstr("""
    s = Dict(1 => 2)
    println(s[1])
    """)))

    msgs = lintstr("""
    function f()
        a = 1
        d = Dict{Symbol,Int}(:a=>1, :b=>2)
        x = d[a]
        return x
    end
    """)
    @test messageset(msgs) == Set([:E522, :E539])
    @test msgs[1].variable == "d[a]"
    @test contains(msgs[1].message, "indexing Dict")
    @test contains(msgs[1].message, "Int")

    # strings
    msgs = lintstr("""
    function f()
        b = repeat(" ", 10)
        b[:start]
    end
    """)
    @test messageset(msgs) == Set([:E522])
    @test msgs[1].variable == "b[:start]"
    @test contains(msgs[1].message, "indexing String")
    @test contains(msgs[1].message, "with index types Symbol is not supported")

    # zero-dimensional indexing
    msgs = lintstr("""
    d = Dict()
    x = d[]
    """)
    @test messageset(msgs) == Set([:E522, :E539])
    @test contains(msgs[1].message, "indexing Dict")
    @test contains(msgs[1].message, "with no indices is not supported")

    msgs = lintstr("""
    a = ""
    a[]
    """)
    @test messageset(msgs) == Set([:E522])
    @test contains(msgs[1].message, "indexing String with no indices")

    # issue 196
    @test messageset(lintstr("""
    s = Dict(:b => 2)
    println(keys(s)[1])
    """)) == Set([:E522])
end
