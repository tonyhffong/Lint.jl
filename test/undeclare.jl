s = """
function f(x)
    x + y
end
"""
msgs = lintstr( s )
@test( length(msgs) == 1)
@test( contains( msgs[1].message, "Use of undeclared symbol" ) )
