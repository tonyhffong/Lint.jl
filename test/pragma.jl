s = """
function f(x)
    local a = 1
    local b = 2
    lintpragma( "Ignore unused a")
    return x+b
end
"""
msgs = lintstr(s)
@test( isempty( msgs ) )
s = """
function f(x)
    local a = 1
    local b = 2
    c = "a"
    lintpragma( "Ignore unused " * c )
    return x+b
end
"""
msgs = lintstr(s)
@test( length( msgs )==2 )
