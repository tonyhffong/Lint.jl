s = """
s = "a" + "b"
"""
msgs = lintstr( s )
@test( contains( msgs[1].message, "String uses * to concat"))

s = """
s = String(1)
"""
msgs = lintstr( s )
@test( contains( msgs[1].message, "You want string"))

s = """
b = string( 12 )
s = "a" + b
"""
msgs = lintstr( s )
@test( contains( msgs[1].message, "String uses * to concat"))
