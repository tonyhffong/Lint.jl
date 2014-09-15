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
s = """
function f( x::Array{Float64,2} )
    y = x[1,2,3]
    y
end
"""
msgs = lintstr( s )
@test( contains( msgs[1].message, "has more indices than dimensions" ) )
s = """
function f( x::Array{Float64,2} )
    x[1,2,3]
end
"""
msgs = lintstr( s )
@test( contains( msgs[1].message, "has more indices than dimensions" ) )
s = """
function f( x::Array{Float64,2} )
    y = x[:,1]
    for i in y
        println( i )
    end
end
"""
msgs = lintstr( s )
@test( isempty( msgs ) )
s = """
function f( x::Array{Float64,2} )
    y = x[1,1]
    lintpragma( "Info type y")
end
"""
msgs = lintstr( s )
@test( contains( msgs[1].message, "typeof( y ) == Float64" ) )
