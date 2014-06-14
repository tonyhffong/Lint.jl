s = """
function f( x; y = 1, z::Int = 4)
    x + y
end

f( 1; y = 3 )

z = Dict{ Symbol, Any }()
"""
msgs = lintstr(s)

@assert( isempty(msgs) )
