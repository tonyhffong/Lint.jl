s = """
e = 1
"""
msgs = lintstr(s)
@test msgs[1].code == 351
@test contains(msgs[1].message, "mathematical constant")
