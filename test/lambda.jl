s = """
function f()
    local x = 1
    g  = x-> x+1
    g(x)
end
"""
msgs = lintstr(s)

@assert( contains( msgs[1].message, "Lambda argument" ) )
s = """
function f()
    g  = (x, y::Int, z::Float64=0.0, args... )-> x+1
end
"""
msgs = lintstr(s)

@assert( isempty(msgs) )
