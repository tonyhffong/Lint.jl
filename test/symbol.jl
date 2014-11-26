s = """
s = Symbol( "abc" )
"""
msgs = lintstr( s )

if VERSION < v"0.4.0-dev+1830"
    @test( contains( msgs[1].message, "symbol() instead of Symbol" ) )
else
    @test isempty( msgs )
end

s = """
if VERSION < v"0.4-"
    s = symbol( "end" )
else
    s = Symbol( "end" )
end
"""
msgs = lintstr( s )
@test isempty( msgs )
