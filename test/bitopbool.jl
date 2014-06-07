s = """
f(a,b,c,d) = a & b ? c :
    (d | c ? b : a)
"""
msgs = lintstr(s)
@test( length(msgs)==2)
@test( contains(msgs[1].message, "Bit-wise &") )
@test( contains(msgs[2].message, "Bit-wise |") )
