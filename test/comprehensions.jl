s = """[i for i in 1:2]
"""
msgs = lintstr( s )
@assert( isempty( msgs ) )

if VERSION < v"0.4-"
    s = """{i for i in 1:2}
    """
    msgs = lintstr( s )
    @assert( contains( msgs[1].message, "deprecated by Julia 0.4" ) )

    s = """
    { y1 => y1*y1 for y1 in 1:2 }
    """
    msgs = lintstr( s )
    @assert( contains( msgs[1].message, "deprecated by Julia 0.4" ) )
end

s = """
[j => j*j for j in 1:2 ]
"""
msgs = lintstr( s )
@assert( isempty( msgs ) )

s = """
(Int=>Int)[ y2 => y2*y2 for y2 in 1:2 ]
"""
msgs = lintstr( s )
@assert( isempty( msgs ) )
