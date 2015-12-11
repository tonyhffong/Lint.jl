s = """
    (a,b) = (1,2,3)
"""
msgs = lintstr(s)
@test msgs[1].code == 418
@test contains(msgs[1].message, "RHS is a tuple of")

s = """
function f()
    (a,b,c) = (1,2,3)
    return (b,c,a)
end
"""
msgs = lintstr(s)
@test isempty(msgs)
