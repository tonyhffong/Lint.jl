s = """
r = [[1,2], [3,4]]
"""
msgs = lintstr( s )
@test( contains( msgs[1].message, "Nested vcat" ) )
s = """
x = {[1,2],[7,8]}
y = Array[ [1,2], [3,4] ]
"""
msgs = lintstr( s )
@test( isempty( msgs ) )
