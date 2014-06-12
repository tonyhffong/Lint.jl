s = """
function f(x)
    x + y
end
"""
msgs = lintstr( s )
@test( length(msgs) == 1)
@test( contains( msgs[1].message, "Use of undeclared symbol" ) )

s = """
function f(x)
    if x > 1
        local i = 1
        println(i)
        i = i + 1
    end
    i = 1
    i
end
"""
msgs = lintstr(s)
@test( length(msgs) == 0 )

s = """
function f(x)
    try
        x > 1
        local i = 1
        println(i)
        i = i + 1
    end
    i = 1
    i
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "used in a local scope"))
