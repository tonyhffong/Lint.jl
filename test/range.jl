s = """
r = 5:1
"""
msgs = lintstr(s)
@test msgs[1].code == :E433
@test occursin(msgs[1].message, "for a decreasing range, use a negative step e.g. 10:-1:1")

s = """
x = [1,2,7,8]
y = [3,4,5,6]
splice!(x, 3:2, y)
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
function f(r::UnitRange)
    return r == 0:-1
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
function f(r::UnitRange)
    a = r[2]
    b = r[3:4]
    @lintpragma("Info type r")
    @lintpragma("Info type a")
    @lintpragma("Info type b")
    (a,b)
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test occursin(msgs[1].message, "typeof(r) == UnitRange")
@test msgs[2].code == :I271
@test occursin(msgs[2].message, "typeof(a) == Any")
@test msgs[3].code == :I271
@test occursin(msgs[3].message, "typeof(b) == UnitRange")
