s = """
module test; if true; end
"""
msgs = lintstr(s)
@test msgs[1].code == 112
@test contains(msgs[1].message, "incomplete:")

s = """
2 +
"""
msgs = lintstr(s)
@test msgs[1].code == 112
@test contains(msgs[1].message, "incomplete:")
