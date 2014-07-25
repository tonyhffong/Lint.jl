s = """[i for i in 1:2]
"""
msgs = lintstr( s )
@assert( isempty( msgs ) )

s = """
[j => j*j for j in 1:2 ]
"""
msgs = lintstr( s )
@assert( isempty( msgs ) )
