s = """
function f()
    call = "hi" # this is just asking for trouble
    call
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E332
@test contains(msgs[1].message, "call should not be used as a variable name")

s = """
function f()
    var = "hi" # this is just asking for trouble
    var
end
"""
msgs = lintstr(s)
@test msgs[1].code == :W356
@test contains(msgs[1].message, "var as a local variable might cause confusion")
