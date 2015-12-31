s = """
function f()
    call = "hi" # this is just asking for trouble
    call
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E332
@test msgs[1].variable == "call"
@test contains(msgs[1].message, "should not be used as a variable name")

s = """
function f()
    var = "hi" # this is just asking for trouble
    var
end
"""
msgs = lintstr(s)
@test msgs[1].code == :W356
@test msgs[1].variable == "var"
@test contains(msgs[1].message, "local variable might cause confusion with a synonymous " *
    "export from Base")
