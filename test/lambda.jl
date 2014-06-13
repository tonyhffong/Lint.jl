s = """
function f()
    local x = 1
    g  = x-> x+1
    g(x)
end
"""
msgs = lintstr(s)

@assert( contains( msgs[1].message, "Lambda argument" ) )
