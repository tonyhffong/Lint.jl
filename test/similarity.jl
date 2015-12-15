s = """
function f(s,t,m)
s.x = m[1,1] * t.x + m[1,2] * t.y + m[1,3] * t.z
s.y = m[2,1] * t.x + m[2,2] * t.y + m[2,3] * t.z
s.z = m[3,1] * t.x + m[3,2] * t.y + m[3,3] * t.z
return(s)
end
"""

msgs = lintstr(s)
@test isempty(msgs)

# can you spot the error?
s = """
function f(s,t,m)
s.x = m[1,1] * t.x + m[1,2] * t.y + m[1,3] * t.z
s.y = m[2,1] * t.x + m[2,2] * t.y + m[2,3] * t.z
s.z = m[3,1] * t.x + m[3,2] * t.x + m[3,3] * t.z
return(s)
end
"""

ctx = LintContext()
filter!(i->!(i==Lint.LintIgnore(:W651, "")), ctx.ignore)
msgs = lintstr(s, ctx)
@test length(msgs) == 1
@test msgs[1].code == 651
@test contains(msgs[1].message, "looks different")
