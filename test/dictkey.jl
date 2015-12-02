s = """@compat Dict(:a=>1, :b=>2, :a=>3 )"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "Duplicate key" ) )
@test( contains( msgs[2].message, "Use explicit Dict{K,V}() for better performances" ) )

s = """
@compat Dict( :a=>Date( 2014,1,1 ), :b=>Date( 2015,1,1 ) )
"""
msgs = lintstr( s )
@test( contains( msgs[1].message, "Use explicit Dict{K,V}() for better performances" ) )

s = """
@compat Dict{Symbol,Int}( :a=>1, :b=>"" )
"""
msgs = lintstr( s )
@test( contains( msgs[1].message, "Multiple value types detected" ) )

s = """
@compat Dict{Symbol,Int}( :a=>1, "b"=>2 )
"""
msgs = lintstr( s )
@test( contains( msgs[1].message, "Multiple key types detected" ) )

