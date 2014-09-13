s = """
function f(x)
    local y::Float64 = 1
    x + y
end
"""
msgs = lintstr( s )
@test( contains( msgs[1].message, "but assign a value of") )
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
s = """
function f(x::Int)
    push!( x, 1)
end
"""
msgs = lintstr( s )
@test( contains( msgs[1].message, "no method found") )

s = """
function f(x)
    d = (Symbol=>Int)[:a=>1, :b=>2 ]
    for i in d
    end
    return x
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "iteration over dictionary uses a (k,v) tuple" ))
