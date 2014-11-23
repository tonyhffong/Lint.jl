s = """
function f()
    call = "hi" # this is just asking for trouble
    call
end
"""
msgs = lintstr( s )
@test contains( msgs[1].message, "You should not use 'call' as a variable name")
