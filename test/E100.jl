@testset "E100" begin
    msgs = lintstr("""
    function f(x, y)
        using Base.Meta
        isexpr(x, :call) ? y : 0
    end
    """)
    @test messageset(msgs) == Set([:E100, :E321])
    @test occursin(msgs[1].message, "using expression must be at top level")

    msgs = lintstr("""
    function f(x, y)
        import Lint
        isexpr(x, :call) ? y : 0
    end
    """)
    @test messageset(msgs) == Set([:E100, :E321])
    @test occursin(msgs[1].message, "import expression must be at top level")

    msgs = lintstr("""
    function f(x, y)
        export f
        isexpr(x, :call) ? y : 0
    end
    """)
    @test messageset(msgs) == Set([:E100, :E321])
    @test occursin(msgs[1].message, "export expression must be at top level")
end
