s = """
f(a,b,c,d) = a & b ? c :
    (d | c ? b : a)
"""
msgs = lintstr(s)
@test length(msgs)==2
@test msgs[1].code == :W442
@test contains(msgs[1].message, "bit-wise &")
@test msgs[2].code == :W442
@test contains(msgs[2].message, "bit-wise |")
