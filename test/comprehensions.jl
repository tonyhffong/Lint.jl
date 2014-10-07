s = """[i for i in 1:2]
"""
msgs = lintstr( s )
@assert( isempty( msgs ) )

s = """{i for i in 1:2}
"""
msgs = lintstr( s )
if VERSION < v"0.4-"
    @assert( contains( msgs[1].message, "deprecated by Julia 0.4" ) )
else
    @assert( isempty( msgs ) )
end

s = """
[j => j*j for j in 1:2 ]
"""
msgs = lintstr( s )
@assert( isempty( msgs ) )

s = """
{ y1 => y1*y1 for y1 in 1:2 }
"""
msgs = lintstr( s )
if VERSION < v"0.4-"
    @assert( contains( msgs[1].message, "deprecated by Julia 0.4" ) )
else
    @assert( isempty( msgs ) )
end

s = """
(Int=>Int)[ y2 => y2*y2 for y2 in 1:2 ]
"""
msgs = lintstr( s )
@assert( isempty( msgs ) )
