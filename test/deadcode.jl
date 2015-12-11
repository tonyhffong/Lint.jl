s = """
function f(x)
    return x+1
    println(x)
end
"""
msgs = lintstr(s)
@test length(msgs) == 1
@test msgs[1].code == 641
@test contains(msgs[1].message, "unreachable")
