s = """
s = "a" + "b"
"""
msgs = lintstr( s )
@test( contains( msgs[1].message, "String uses * to concat"))

s = """
function f(x)
    Dict("a" + "b" => x)
end
"""
msgs = lintstr(s)
@test contains( msgs[1].message, "String uses * to concat" )

s = """
s = String(1)
"""
msgs = lintstr( s )
@test( contains( msgs[1].message, "You want string"))

s = """
b = string( 12 )
s = "a" + b
"""
msgs = lintstr( s )
@test( contains( msgs[1].message, "String uses * to concat"))
s = """
function f()
    b = repeat( " ", 10 )
    @lintpragma( "Info type b")
    b
end
"""
msgs = lintstr( s )
@test( contains( msgs[1].message, "typeof( b ) == ASCIIString" ) )
s = """
function f()
    b = repeat( " ", 10 )
    b[ :start ]
end
"""
msgs = lintstr( s )
@test( contains( msgs[1].message, "string[] expects Integer, provided Symbol" ) )
