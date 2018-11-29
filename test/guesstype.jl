s = """
a = begin end
"""
@test Lint.guesstype(parse(s), LintContext()) == Void
msgs = lintstr(s)
@test isempty(msgs)

@test Lint.iscolon(:(:))
@test Lint.iscolon(:(Colon()))
