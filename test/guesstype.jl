@testset "correctly detect stdlib objects" begin
    @test Lint.stdlibobject(:var) ≡ nothing
    @test Lint.stdlibobject(:axes) !== nothing
end

@testset "Handle empty code block" begin
    let s = """
        a = begin end
        """,
        ex=Meta.parse(s)
        @test Lint.get_tag_per_condition(ex) == Lint.AssignTag
        @test Lint.guesstype(ex, LintContext()) == Nothing
        msgs = lintstr(s)
        @test isempty(msgs)
    end
end
@testset "Colon (no parameters)" begin
    @test Lint.iscolon(:(:))
    @test Lint.iscolon(:(Colon()))
end

@testset "Dictionary" begin
    let s = """
        Dict{Symbol,Int}(:a=>1, :b=>2)
        """,
        ex=Meta.parse(s)
        @test Lint.guesstype(ex, LintContext()) ≠ Any
    end
end

@testset "Array-of-Tuples" begin
    let ex = :([(1, 2, 3), (4, 5, 6)]),
        @test Lint.guesstype(ex, LintContext()) ≠ Any # currently failing
    end
end
