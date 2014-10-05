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
if VERSION < v"0.4-"
    @test( contains( msgs[2].message, "Untyped dictionary {a=>b,...}, may be deprecated by Julia 0.4" ) )
    @test( contains( msgs[3].message, "Use explicit (K=>V)[] for better performances" ) )
else
    @test( contains( msgs[2].message, "Use explicit (K=>V)[] for better performances" ) )
end

s = """
{ :a=>Date( 2014,1,1 ), :b=>Date( 2015,1,1 ) }
"""
msgs = lintstr( s )

if VERSION < v"0.4-"
    @test( contains( msgs[1].message, "Untyped dictionary {a=>b,...}, may be deprecated by Julia 0.4" ) )
    @test( contains( msgs[2].message, "Use explicit (K=>V)[] for better performances" ) )
else
    @test( contains( msgs[1].message, "Use explicit (K=>V)[] for better performances" ) )
end

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
