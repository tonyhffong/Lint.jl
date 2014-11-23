s = """
function f(x)
    local a = 1
    local b = 2
    @lintpragma( "Ignore unused a")
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
    @lintpragma( "Ignore unused " * c )
    return x+b
end
"""
msgs = lintstr(s)
@test( length( msgs )==2 )

# @lintpragma can also be used to generate messages
s = """
function f(x)
    local b = 2
    @lintpragma( "Info type b")
    return x+b
end
"""
msgs = lintstr(s)
@test( length( msgs ) == 1)
@test( contains( msgs[1].message, "typeof( b ) == Int" ) )
s = """
function f(x)
    local b = 2
    @lintpragma( "Warn type b")
    return x+b
end
"""
msgs = lintstr(s)
@test( length( msgs ) == 1)
@test( contains( msgs[1].message, "typeof( b ) == Int" ) )
s = """
function f(x)
    local b = 2
    @lintpragma( "Error type b")
    return x+b
end
"""
msgs = lintstr(s)
@test( length( msgs ) == 1)
@test( contains( msgs[1].message, "typeof( b ) == Int" ) )
s = """
function f(x)
    local b = 2
    @lintpragma( "Print type b")
    return x+b
end
"""
msgs = lintstr(s)
@test( isempty( msgs ) )
s = """
function f(x)
    local b = 2
    @lintpragma( "Print type b[1")
    return x+b
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "Incomplete expression " ) )
s = """
function f(x)
    local b = 2
    @lintpragma( "Info me my own reminder")
    return x+b
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "my own reminder" ) )
s = """
function f(x)
    local b = 2
    @lintpragma( "Info me " * string( b ) )
    return x+b
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "@lintpragma must be called using only string literals" ) )

s = """
function f(x)
    local a = 1
    local b = 2
    @lintpragma( "Ignore unused a")
    return x+a+b
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "Unused @lintpragma Ignore unused a" ) )
