s = """
[ :a=>1, :b=>2, :a=>3]
"""
msgs = lintstr( s )

@test( contains( msgs[1].message, "Duplicate key" ) )
if VERSION < v"0.4-"
    @test( contains( msgs[2].message, "may be deprecated by Julia 0.4" ) )
end

s = """
{ :a=>1, :b=>2, :a=>3}
"""
msgs = lintstr( s )

@test( contains( msgs[1].message, "Duplicate key" ) )
if VERSION < v"0.4-"
    @test( contains( msgs[2].message, "@compat Dict{K,V}(a=>b,...) for better performances" ) )
end

s = """
{ :a=>Date( 2014,1,1 ), :b=>Date( 2015,1,1 ) }
"""
msgs = lintstr( s )
if VERSION < v"0.4-"
    @test( contains( msgs[1].message, "Use explicit @compat Dict{K,V}(a=>b,...) for better performances" ) )
end

s = """
[ :a=>1, :b=>"" ]
"""
msgs = lintstr( s )
@test( contains( msgs[1].message, "Multiple value types detected" ) )
if VERSION < v"0.4-"
    @test( contains( msgs[2].message, "may be deprecated by Julia 0.4" ) )
end

s = """
[ :a=>1, "b"=>2 ]
"""
msgs = lintstr( s )
@test( contains( msgs[1].message, "Multiple key types detected" ) )
if VERSION < v"0.4-"
    @test( contains( msgs[2].message, "may be deprecated by Julia 0.4" ) )
end

s = """
(Symbol=>Int)[ :a=>1, :b=>2 ]
"""
msgs = lintstr( s )
if VERSION < v"0.4-"
    @test( contains( msgs[1].message, "may be deprecated by Julia 0.4" ) )
else
    @test( isempty( msgs ) )
end

s = """
(Any=>Any)[ :a=>1, :b=>2 ]
"""
msgs = lintstr( s )
if VERSION < v"0.4-"
    @test( contains( msgs[1].message, "may be deprecated by Julia 0.4" ) )
else
    @test( isempty( msgs ) )
end
