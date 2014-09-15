s = """
    (a,b) = (1,2,3)
"""
msgs = lintstr( s )
@assert( contains( msgs[1].message, "RHS is a tuple of" ) )
s = """
    (a,b,c) = (1,2,3)
"""
msgs = lintstr( s )
@assert( isempty( msgs ) )
