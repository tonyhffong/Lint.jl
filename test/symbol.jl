s = """
s = Symbol( "abc" )
"""
msgs = lintstr( s )
@test( contains( msgs[1].message, "symbol conversion" ) )
