s = """
function f(x)
    return x+1
    println(x)
end
"""
msgs = lintstr(s)
@test length(msgs) == 1
@test msgs[1].code == :W641
@test occursin(msgs[1].message, "unreachable code after return")
