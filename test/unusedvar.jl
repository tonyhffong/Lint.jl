s = """
function f(x)
    local a = 1
    local b::Int = 2
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
s = """
function f(x)
    let a = 1
        b = 2
        y = x+b
        println( y )
    end
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "declared but not used" ))
s = """
function f(x)
    local a::Int
    local b = 2::Int # type assertion/conversion
    return x+b
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "declared but not used" ))
s = """
function f(x)
    local a
    local b = 2::Int # type assertion/conversion
    return x+b
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "declared but not used" ))
s = """
function f(x)
    x+=1
end
"""
msgs = lintstr(s)
@test( isempty( msgs ) )

s = """
function f(x...)
    Dict(x...)
end
"""
msgs = lintstr(s)
@test isempty( msgs )
