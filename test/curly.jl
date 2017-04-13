@testset "W447" begin
    msgs = lintstr("a = Dict{:Symbol, Any}")
    @test messageset(msgs) == Set([:W447])
    @test contains(msgs[1].message, "type parameter for Dict")

    msgs = lintstr("a = Dict{:Symbol, Any}()")
    @test messageset(msgs) == Set([:W447])
    @test contains(msgs[1].message, "type parameter for Dict")

    @test isempty(lintstr("a = Set{Tuple{Int, Int}}()"))

    msgs = lintstr("""
    b = :Symbol
    a = Dict{b, Any}()
    """)
    @test messageset(msgs) == Set([:W447])
    @test contains(msgs[1].message, "type parameter for Dict")

    msgs = lintstr("a = Array{2, Int64}()")
    @test_broken messageset(msgs) == Set([:W447])
    @test contains(msgs[1].message, "type parameter for Array")
end

@testset "Curly" begin
    s = """
    a = Set{(Int, Int)}()
    """
    msgs = lintstr(s)
    @test msgs[1].code == :W441
    @test contains(msgs[1].message, "probably illegal use inside curly")

    s = """
    a = Array{Int64, 5, 5}()
    """
    msgs = lintstr(s)
    @test msgs[1].code == :W446
    @test contains(msgs[1].message, "too many type parameters")

    s = """
    a = Ptr{Void}
    """
    msgs = lintstr(s)
    @test isempty(msgs)

    s = """
    @traitfn ft1{X,Y; Cmp{X,Y}}(x::X, y::Y) = x > y ? 5 : 6
    """
    msgs = lintstr(s)
    @test isempty(msgs)
end
