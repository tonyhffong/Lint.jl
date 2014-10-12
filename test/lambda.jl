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
function f(x)
    map( x-> x+1, x )
end
"""
msgs = lintstr(s)
@assert( contains( msgs[1].message, "Lambda argument" ) )
s = """
x = 1
function f()
    g  = x-> x+1
    return g
end
"""
msgs = lintstr(s)
@assert( contains( msgs[1].message, "Lambda argument" ) )
s = """
function f()
    @lintpragma( "Ignore unused y")
    @lintpragma( "Ignore unused z")
    @lintpragma( "Ignore unused args")
    g  = (x, y::Int, z::Float64=0.0, args... )-> x+1
end
"""
msgs = lintstr(s)

@assert( isempty(msgs) )
s = """
ntuple( 4, _->0)
"""
msgs = lintstr(s)
@assert( isempty( msgs ) )
