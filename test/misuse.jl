# We have to be able to handle illegal and unexpected things
s = """
1=1
"""
msgs = lintstr(s)
@test msgs[1].code == 171
@test contains(msgs[1].message, "LHS in assignment not understood by Lint")

s = """
d = Dict()
x = d[]
"""
msgs = lintstr(s)
@test msgs[1].code == 121
@test contains(msgs[1].message, "Lint does not understand")

s = """
a = ""
a[]
"""
msgs = lintstr(s)
@test msgs[1].code == 121
@test contains(msgs[1].message, "Lint does not understand")
