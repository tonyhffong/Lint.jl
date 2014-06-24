
s = """
type MyType{Int64}
end
"""
msgs = lintstr(s)
@assert( contains( msgs[1].message, "unrelated to the type" ) )
s = """
type MyType{Int64} <: Float64
end
"""
msgs = lintstr(s)
@assert( contains( msgs[1].message, "unrelated to the type" ) )
