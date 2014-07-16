Lint.addDummyDeprecates()

s = """
function testDep1( x )
    x
end
"""
msgs = lintstr(s)

@assert( contains(msgs[1].message, "generic deprecate message" ) )
s = """
function testDep2( x::Int )
    x
end
"""
msgs = lintstr(s)
@assert( contains(msgs[1].message, "generic deprecate message" ) )

s = """
function testDep3{T <: Real}( x::Array{T,1} )
    x
end
"""
msgs = lintstr(s)
@assert( contains( msgs[1].message, "generic deprecate message" ) )
