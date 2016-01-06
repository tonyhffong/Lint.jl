s = """
e = 1
"""
msgs = lintstr(s)
@test msgs[1].code == :W351
@test contains(msgs[1].message, "redefining mathematical constant")
