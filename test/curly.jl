s = """
a = Dict{ :Symbol, Any}
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "Probably illegal use of" ) )

s = """
a = Dict{ :Symbol, Any}()
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "Probably illegal use of" ) )

s = """
a = Set{ ( Int, Int ) }()
"""
msgs = lintstr(s)
@test( isempty( msgs ) )

s = """
b = :Symbol
a = Dict{ b, Any}()
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "Probably illegal use of" ) )

s = """
a = Ptr{ Void }
"""
msgs = lintstr(s)
@test( isempty( msgs ) )

s = """
@traitfn ft1{X,Y; Cmp{X,Y}}(x::X,y::Y)  = x>y ? 5 : 6"
"""
msgs = lintstr( s )
@test( isempty( msgs ) )

