s = """
function f(x)
    return x+1
    println( x )
end
"""

msgs = lintstr(s)
@test(length(msgs)==1)
@test(contains( msgs[1].message, "Unreachable" ) )
