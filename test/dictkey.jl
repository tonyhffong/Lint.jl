s = """
[ :a=>1, :b=>2, :a=>3]
"""
msgs = lintstr( s )

@test( contains( msgs[1].message, "Duplicate key" ) )

s = """
{ :a=>1, :b=>2, :a=>3}
"""
msgs = lintstr( s )

@test( contains( msgs[1].message, "Duplicate key" ) )
