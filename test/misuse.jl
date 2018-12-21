# We have to be able to handle illegal and unexpected things
s = """
1=1
"""
msgs = lintstr(s)
@test msgs[1].code == :I171
@test occursin("LHS in assignment not understood by Lint", msgs[1].message)

s = """
local 5
"""
msgs = lintstr(s)
@test msgs[1].code == :E135
@test msgs[1].variable == "5"
@test occursin("local declaration not understood by Lint", msgs[1].message)

s = """
a = 5
if a
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E511
@test msgs[1].variable == "a"
@test occursin("apparent non-Bool type", msgs[1].message)

s = """
d = Dict{float, float}()
"""
msgs = lintstr(s)

if VERSION < v"0.5.0-dev+2959"
@test msgs[1].code == :W441
@test msgs[2].code == :W441
else
@test msgs[1].code == :W447
@test occursin("it should be of type Type", msgs[1].message)
@test msgs[2].code == :W447
@test occursin("it should be of type Type", msgs[2].message)
end
