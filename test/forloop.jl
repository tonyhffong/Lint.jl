s = """
function f(x)
    d = @compat Dict{Symbol,Int}(:a=>1, :b=>2 )
    for i in d
    end
    return x
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "Iteration generates tuples of" ))
s = """
function f(x)
    while false
        println( "test" )
    end
    return x
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "while false block is unreachable" ))
s = """
function f(x)
    arr = Array(Int, 1)
    for i in [1,2], j in arr
        println( i*j)
    end
    return x
end
"""
msgs = lintstr(s)
@test( isempty( msgs ) )
s = """
function f(x)
    for i in (1,2,3)
        println( i)
    end
    return x
end
"""
msgs = lintstr(s)
@test( isempty( msgs ) )

s = """
function f(x::Int)
    @lintpragma( "Info type x")
    for i in x
        println( i )
    end
    return x
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "typeof( x ) == Int" ) )
@test( contains( msgs[2].message, "Iteration works for a number but it may be a typo" ) )
s = """
function f(x=1)
    @lintpragma( "Info type x")
    return x
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "typeof( x ) == Int" ) )
s = """
function f(x::Int8=int8(1))
    @lintpragma( "Info type x")
    return x
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "typeof( x ) == Int8" ) )
s = """
function f(c::Char)
    x = convert( Int, c )
    @lintpragma( "Info type x")
    return x
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "typeof( x ) == Int" ) )
s = """
function f(a::Array{Int,1})
    for i in enumerate( a )
        println( i )
    end
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "Iteration generates tuples of" ) )
