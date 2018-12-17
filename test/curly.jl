@testset "W447" begin
    msgs = lintstr("a = Dict{:Symbol, Any}")
    @test messageset(msgs) == Set([:W447])
    @test occursin("type parameter for Dict", msgs[1].message)

    msgs = lintstr("a = Dict{:Symbol, Any}()")
    @test messageset(msgs) == Set([:W447])
    @test occursin("type parameter for Dict", msgs[1].message)

    @test isempty(lintstr("a = Set{Tuple{Int, Int}}()"))

    msgs = lintstr("""
    b = :Symbol
    a = Dict{b, Any}()
    """)
    @test messageset(msgs) == Set([:W447])
    @test occursin("type parameter for Dict", msgs[1].message)

    msgs = lintstr("a = Array{2, Int64}()")
    @test messageset(msgs) == Set([:W447])
    @test occursin("type parameter for Array", msgs[1].message)
end

@testset "Curly" begin
    s = """
    a = Set{(Int, Int)}()
    """
    msgs = lintstr(s)
    @test msgs[1].code == :W441
    @test occursin("probably illegal use inside curly", msgs[1].message)

    s = """
    a = Array{Int64, 5, 5}()
    """
    msgs = lintstr(s)
    @test msgs[1].code == :W446
    @test occursin("too many type parameters", msgs[1].message)

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
