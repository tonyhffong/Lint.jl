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
function f(x)
    for i in 1
        println( i )
    end
    return x
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "Iteration works for a single number" ) )
