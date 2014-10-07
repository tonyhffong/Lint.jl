s = """
@doc "this is a test" -> f() = 0
"""
msgs = lintstr( s )
@assert isempty( msgs )
s = "@doc \"\"\"this is a test\"\"\" -> f() = 0"
msgs = lintstr( s )
@assert isempty( msgs )
s = """
@doc "this is a test"
f() = 0
"""
msgs = lintstr( s )
@assert contains( msgs[1].message, "Did you forget an -> after @doc")
