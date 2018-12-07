s = """
throw(MethodError("blah"))
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
MethodError("blah")
"""
msgs = lintstr(s)
@test msgs[1].code == :W448
@test occursin(msgs[1].message, "MethodError is an Exception but it is not enclosed in a throw")
