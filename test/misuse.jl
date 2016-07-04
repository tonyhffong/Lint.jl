# We have to be able to handle illegal and unexpected things
s = """
1=1
"""
msgs = lintstr(s)
@test msgs[1].code == :I171
@test contains(msgs[1].message, "LHS in assignment not understood by Lint")

s = """
d = Dict()
x = d[]
"""
msgs = lintstr(s)
@test msgs[1].code == :E121
@test contains(msgs[1].message, "Lint does not understand the expression")

s = """
a = ""
a[]
"""
msgs = lintstr(s)
@test msgs[1].code == :E121
@test contains(msgs[1].message, "Lint does not understand the expression")

s = """
local 5
"""
msgs = lintstr(s)
@test msgs[1].code == :E135
@test msgs[1].variable == "5"
@test contains(msgs[1].message, "local declaration not understood by Lint")

s = """
a = 5
if a
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E511
@test msgs[1].variable == "a"
@test contains(msgs[1].message, "apparent non-Bool type")

s = """
d = Dict{float, float}()
"""
msgs = lintstr(s)

if VERSION < v"0.5.0-dev+2959"
@test msgs[1].code == :W441
@test msgs[2].code == :W441
else
@test msgs[1].code == :W447
@test contains(msgs[1].message, "it should be of type DataType")
@test msgs[2].code == :W447
@test contains(msgs[2].message, "it should be of type DataType")
end
