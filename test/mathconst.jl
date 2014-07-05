s = """
e = 1
"""
msgs = lintstr( s )

@test( contains( msgs[1].message, "mathematical constant" ) )
