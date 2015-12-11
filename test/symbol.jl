s = """
s = Symbol("abc")
"""
msgs = lintstr(s)

@test isempty(msgs)

s = """
if VERSION < v"0.4-"
    s = symbol("end")
else
    s = Symbol("end")
end
"""
msgs = lintstr(s)
@test isempty(msgs)
