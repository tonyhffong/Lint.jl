s = """
e = 1
"""
msgs = lintstr( s )

@test( contains( msgs[1].message, "Core/Main export 'e'" ) )
@test( contains( msgs[2].message, "mathematical constant" ) )
