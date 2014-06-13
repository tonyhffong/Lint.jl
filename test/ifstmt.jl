s = """
wrap(pos::Int, len::Int) = true ? 1 : (pos > len ? len : pos)
"""
msgs = lintstr( s )
@test( length(msgs)==1 )
@test( contains( msgs[1].message, "false branch" ) )
@test( msgs[1].line == 1 )

s = """
wrap(pos::Int, len::Int) = false ? 1 : (pos > len ? len : pos)
"""
msgs = lintstr( s )
@test( length(msgs)==1 )
@test( contains( msgs[1].message, "true branch" ) )
@test( msgs[1].line == 1 )

s = """
f(x) = (x=1)? 1 : 2 # clearly not what we want
"""
msgs = lintstr(s )
@test( contains( msgs[1].message, "if-predicate") )

s = """
f(x,y) = (0 <= x < y = 6)? 1 : 2 # clearly not what we want
"""
msgs = lintstr(s )
@test( contains( msgs[1].message, "if-predicate") )
