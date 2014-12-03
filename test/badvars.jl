s = """
function f()
    call = "hi" # this is just asking for trouble
    call
end
"""
msgs = lintstr( s )
@test contains( msgs[1].message, "You should not use 'call' as a variable name")

s = """
function f()
    var = "hi" # this is just asking for trouble
    var
end
"""
msgs = lintstr( s )
@test contains( msgs[1].message, "Core/Main export 'var' and should not be overriden")
