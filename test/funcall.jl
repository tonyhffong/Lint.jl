s = """
function f( x; y = 1, z::Int = 4)
    x + y
end

f( 1; y = 3 )

z = Dict{ Symbol, Any }()
"""
msgs = lintstr(s)

@assert( isempty(msgs) )
s = """
function f{T}( x::T, y::T )
    a = Array{ T, 1 }()
    append!( a,[ x, y ] )
    a
end
"""
msgs = lintstr(s)

@assert( isempty(msgs) )
s = """
function f( x, args...)
    x + length(args)
end
"""
msgs = lintstr(s)

@assert( isempty(msgs) )
s = """
function f( x, args..., bogus...)
    x + length(args) + length( bogus )
end
"""
msgs = lintstr(s)

@assert( contains( msgs[1].message, "can only be the last argument" ) )
