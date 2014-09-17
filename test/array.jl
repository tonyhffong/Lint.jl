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
    @lintpragma( "Info type y")
end
"""
msgs = lintstr( s )
@test( contains( msgs[1].message, "typeof( y ) == Float64" ) )
s = """
function f(t)
    x1 = zeros( 1,2 )
    x2 = zeros( Int64,2,2 )
    x3 = zeros( t, 2, 2 )
    x4 = zeros( x1 )
    @lintpragma( "Info type x1")
    @lintpragma( "Info type x2")
    @lintpragma( "Info type x3")
    @lintpragma( "Info type x4")
end
"""
msgs = lintstr( s )
@test( contains( msgs[1].message, "typeof( x1 ) == Array{Float64,2}" ) )
@test( contains( msgs[2].message, "typeof( x2 ) == Array{Int64,2}" ) )
@test( contains( msgs[3].message, "typeof( x3 ) == Array{T,N}" ) )
@test( contains( msgs[4].message, "typeof( x4 ) == Array{Float64,2}" ) )

# more array function
s = """
function f(t::Array{Int64,2}, m, n )
    x1 = slicedim( t, 2, 1 )
    x2 = reshape( t, 1 )
    x3 = reshape( t, (1,2) )
    x4 = reshape( m, (1,2) )
    x5 = reshape( t, n )
    x6 = reshape( t, 1,2 )
    @lintpragma( "Info type x1")
    @lintpragma( "Info type x2")
    @lintpragma( "Info type x3")
    @lintpragma( "Info type x4")
    @lintpragma( "Info type x5")
    @lintpragma( "Info type x6")
end
"""
msgs = lintstr( s )
@test( contains( msgs[1].message, "typeof( x1 ) == Array{Int64,2}" ) )
@test( contains( msgs[2].message, "typeof( x2 ) == Array{Int64,1}" ) )
@test( contains( msgs[3].message, "typeof( x3 ) == Array{Int64,2}" ) )
@test( contains( msgs[4].message, "typeof( x4 ) == Any" ) )
@test( contains( msgs[5].message, "typeof( x5 ) == Array{Int64,N}" ) )
@test( contains( msgs[6].message, "typeof( x6 ) == Array{Int64,2}" ) )

s = """
function f( a::Array{Float64} )
    x = a[1,2]
    @lintpragma( "Info type x")
    return x
end
"""
msgs = lintstr( s )
# it could be Float64, or it could be an array still!
@test( contains( msgs[1].message, "typeof( x ) == Any" ) )
