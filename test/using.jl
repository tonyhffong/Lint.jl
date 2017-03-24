@testset "using" begin
    @test_broken isempty(lintstr("""
    module TmpTestBase
        export foobar
        foobar(x) = x
    end

    module Test
        using ..TmpTestBase
        g(x) = foobar(x)
    end
    """))
end
