s = """
f(a,b,c,d) = a & b ? c :
    (d | c ? b : a)
"""
msgs = lintstr(s)
@test length(msgs)==2
@test msgs[1].code == :I475
@test msgs[1].variable == "&"
@test occursin("bit-wise in a boolean context. (&,|, msgs[1].message) do not have " *
    "short-circuit behavior")
@test msgs[2].code == :I475
@test msgs[2].variable == "|"
@test occursin("bit-wise in a boolean context. (&,|, msgs[2].message) do not have " *
    "short-circuit behavior")
