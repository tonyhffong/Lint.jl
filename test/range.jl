s = """
r = 10:1
"""
msgs = lintstr( s )
@test( contains( msgs[1].message, "decreasing range" ) )
