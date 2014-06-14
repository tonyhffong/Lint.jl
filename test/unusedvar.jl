s = """
function f(x)
    local a = 1
    local b = 2
    return x+b
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "declared but not used" ))
@test( msgs[1].line == 2 )
s = """
function f(x)
    local (a,b) = (1,2)
    return x+b
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "declared but not used" ))
@test( msgs[1].line == 2 )
