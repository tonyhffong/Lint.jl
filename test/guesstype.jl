let s = """
    a = begin end
    """,
    ex=Meta.parse(s)
    @test Lint.get_tag_per_condition(ex) == Lint.AssignTag
    @test Lint.guesstype(ex, LintContext()) == Nothing
    msgs = lintstr(s)
    @test isempty(msgs)
end

@test Lint.iscolon(:(:))
@test Lint.iscolon(:(Colon()))
