@testset "I343" begin
    if VERSION ≥ v"0.6.0-dev.2746"
        @testset "Type Alias Shadowing" begin
            s = """
            const TT = Int64
            @compat SharedVector{X} = SharedArray{X,1}

            type MyType{X}
                t::X
                MyType{X}(x) where X = new(convert(X, x))
            end
            """
            msgs = lintstr(s)
            @test messageset(msgs) == Set([:I343])
            @test msgs[1].variable == "SharedVector"
        end
    end

    msgs = lintstr("""
    e = 1
    """)
    @test messageset(msgs) == Set([:I343])
    @test contains(msgs[1].message, "with same name as export from Base")

    @test isempty(lintstr("""
    import Base: parent
    @compat struct MyType end
    parent(_::MyType) = MyType()
    """))
end
