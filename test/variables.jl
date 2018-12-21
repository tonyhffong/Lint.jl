@testset "Variables basics" begin

    let s = """
    function f()
    x = 0
    x
    end
    """
    @test lintstr(s) == []
    end
    let s = """
    function f()
    x = zeros(10, 10)
    x
    end
    """
    @test lintstr(s) == []
    end
end
