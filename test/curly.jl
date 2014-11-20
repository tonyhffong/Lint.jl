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
b = :Symbol
a = Dict{ b, Any}()
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "Probably illegal use of" ) )
