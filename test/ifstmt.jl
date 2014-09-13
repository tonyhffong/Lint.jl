s = """
wrap(pos::Int, len::Int) = true ? 1 : (pos > len ? len : pos)
"""
msgs = lintstr( s )
@test( length(msgs)==1 )
@test( contains( msgs[1].message, "false branch" ) )
@test( msgs[1].line == 1 )

s = """
wrap(pos::Int, len::Int) = false ? 1 : (pos > len ? len : pos)
"""
msgs = lintstr( s )
@test( length(msgs)==1 )
@test( contains( msgs[1].message, "true branch" ) )
@test( msgs[1].line == 1 )

s = """
f(x) = (x=1)? 1 : 2 # clearly not what we want
"""
msgs = lintstr(s )
@test( contains( msgs[1].message, "if-predicate") )

s = """
f(x) = ifelse(length(x), 1 , 2 ) # clearly not what we want
"""
msgs = lintstr(s )
@test( contains( msgs[1].message, "Incorrect usage of length") )

s = """
f(x,y) = (0 <= x < y = 6)? 1 : 2 # clearly not what we want
"""
msgs = lintstr(s )
@test( contains( msgs[1].message, "if-predicate") )
s = """
function f()
    if true
        println( "hello")
    end
end
"""
msgs = lintstr(s )
@test( contains( msgs[1].message, "redundant if-true") )
s = """
function f()
    v::Array{Int,1} = [ 1,2,3 ]
    if length(v)
        println( "hello")
    end
end
"""
msgs = lintstr(s )
@test( contains( msgs[1].message, "Incorrect usage of length") )
s = """
function f(b::Boolean, x::Int, y::Int)
    a = b ? x : y
    for i in a
        println( i )
    end
end
"""
msgs = lintstr(s )
@test( contains( msgs[1].message, "Iteration works for a number") )
s = """
function f(b::Boolean, x::Int, y::Any)
    a = b ? x : y
    for i in a
        println( i )
    end
end
"""
msgs = lintstr(s )
@test( isempty( msgs ) )
