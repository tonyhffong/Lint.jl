s = """
r = 10:1
"""
msgs = lintstr( s )
@test( contains( msgs[1].message, "decreasing range" ) )
s = """
x = [1,2,7,8]
y = [3,4,5,6]
splice!(x, 3:2, y)
"""
msgs = lintstr( s )
@test( isempty( msgs ) )

s = """
function f( r::UnitRange )
    return r == 0:-1
end
"""
msgs = lintstr( s )
@test( isempty( msgs ) )
