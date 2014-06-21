s = """
s = "a" + "b"
"""
msgs = lintstr( s )
@test( contains( msgs[1].message, "String uses * to concat"))
