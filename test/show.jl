s = """
function f(x)
    local a = 1
    local c = 3
    local b = 2
    return x+b
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "declared but not used" ))
sort!( msgs )
for m in msgs
    println( msgs )
end
