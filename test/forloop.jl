s = """
function f(x)
    for i in [:a=>1, :b=>2 ]
    end
    return x
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "iteration over dictionary uses a (k,v) tuple" ))
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
    for i in [1,2], j in [4,5]
        println( i*j)
    end
    return x
end
"""
msgs = lintstr(s)
@test( isempty( msgs ) )

s = """
function f(x::Int)
    for i in x
        println( i )
    end
    return x
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "Iteration works for a number" ) )
s = """
function f(x=1)
    for i in x
        println( i )
    end
    return x
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "Iteration works for a number" ) )
s = """
function f(x::Int8=int8(1))
    for i in x
        println( i )
    end
    return x
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "Iteration works for a number" ) )
s = """
function f(c::Char)
    x = convert( Int, c )
    for i in x
        println( i )
    end
    return x
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "Iteration works for a number" ) )
s = """
function f(c::Char)
    x = int8(c)
    x = int16(x)
    x = int32(x)
    x = int64(x)
    x = int(x)
    x = Rational(x)
    x = float(x)
    x = Complex(x)
    for i in x
        println( i )
    end
    return x
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "but now assigned" ) )
@test( contains( msgs[end].message, "Iteration works for a number" ) )
