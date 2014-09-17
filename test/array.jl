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
s = """
function f(t)
    x = zeros( 1,2 )
    y = zeros( Int64,2,2 )
    z = zeros( t, 2, 2 )
    lintpragma( "Info type x")
    lintpragma( "Info type y")
    lintpragma( "Info type z")
end
"""
msgs = lintstr( s )
@test( contains( msgs[1].message, "typeof( x ) == Array{Float,2}" ) )
@test( contains( msgs[2].message, "typeof( y ) == Array{Int64,2}" ) )
@test( contains( msgs[3].message, "typeof( z ) == Array{T,N}" ) )
