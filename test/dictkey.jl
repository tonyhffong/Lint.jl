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
@test( contains( msgs[2].message, "Use [] for better performances" ) )

s = """
{ :a=>Date( 2014,1,1 ), :b=>Date( 2015,1,1 ) }
"""
msgs = lintstr( s )

@test( contains( msgs[1].message, "Use [] for better performances" ) )

s = """
[ :a=>1, :b=>"" ]
"""
msgs = lintstr( s )

@test( contains( msgs[1].message, "Multiple value types detected" ) )

s = """
[ :a=>1, "b"=>2 ]
"""
msgs = lintstr( s )

@test( contains( msgs[1].message, "Multiple key types detected" ) )
s = """
(Symbol=>Int)[ :a=>1, :b=>2 ]
"""
msgs = lintstr( s )
@test( isempty( msgs ) )

s = """
(Any=>Any)[ :a=>1, :b=>2 ]
"""
msgs = lintstr( s )
@test( isempty( msgs ) )
