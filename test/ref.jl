s = """
r = [3,2,1]
r[r]
"""
msgs = lintstr(s)
@test msgs[1].code == :E434
@test contains(msgs[1].message, "value at position #1 is the referenced r. Possible typo?")

s = """
r = [3,2,1]
r[1;r]
"""
msgs = lintstr(s)
@test msgs[1].code == :E434
@test contains(msgs[1].message, "value at position #2 is the referenced r. Possible typo?")
