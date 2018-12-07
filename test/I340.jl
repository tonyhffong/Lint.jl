@testset "I340" begin
    msgs = lintstr("""
    function f(x)
        local a = 1
        local b::Int = 2
        return x+b
    end
    """)
    @test messageset(msgs) == Set([:I340])
    @test occursin(msgs[1].message, "unused local variable")
    @test_broken msgs[1].line == 2

    msgs = lintstr("""
    function f(x)
        local (a,b) = (1,2)
        return x+b
    end
    """)
    @test messageset(msgs) == Set([:I340])
    @test occursin(msgs[1].message, "unused local variable")
    @test_broken msgs[1].line == 2

    msgs = lintstr("""
    function f(x)
        let a = 1
            b = 2
            y = x+b
            println(y)
        end
    end
    """)
    @test messageset(msgs) == Set([:I340])
    @test occursin(msgs[1].message, "unused local variable")

    msgs = lintstr("""
    function f(x)
        local a::Int
        local b = 2::Int # type assertion/conversion
        return x+b
    end
    """)
    @test messageset(msgs) == Set([:I340])
    @test occursin(msgs[1].message, "unused local variable")

    msgs = lintstr("""
    function f(x)
        local a
        local b = 2::Int # type assertion/conversion
        return x+b
    end
    """)
    @test messageset(msgs) == Set([:I340])
    @test occursin(msgs[1].message, "unused local variable")

    @test isempty(lintstr("""
    function f(x)
        x+=1
    end
    """))

    @test isempty(lintstr("""
    function f(x...)
        Dict(x...)
    end
    """))
end
