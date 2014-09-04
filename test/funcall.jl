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
function f( x, y, x )
    x + y
end
"""
msgs = lintstr(s)
@assert( contains( msgs[1].message, "Duplicate argument" ) )
s = """
function f{Int64}( x::Int64, y::Int64 )
    x + y
end
"""
msgs = lintstr(s)
@assert( contains( msgs[1].message, "unrelated to the type" ) )
s = """
function f{T<:Int64}( x::T, y::T)
    x + y
end
"""
msgs = lintstr(s)
@assert( contains( msgs[1].message, "leaf type" ) )
s = """
function f{Int<:Real}( x::Int, y::Int)
    x + y
end
"""
msgs = lintstr(s)
@assert( contains( msgs[1].message, "known type" ) )
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
s = """
function f( x=1, y, args...)
    x + length(args) + y
end
"""
msgs = lintstr(s)

@assert( contains( msgs[1].message, "non-default argument following default" ) )
s = """
function f( x, y; z, q=1)
    x + q + y
end
"""
msgs = lintstr(s)

@assert( contains( msgs[1].message, "must have a default" ) )
s = """
function f( x, y; args..., z=1)
    x + length(args) + y
end
"""
msgs = lintstr(s)

@assert( contains( msgs[1].message, "can only be the last argument" ) )
s = """
function f( x, args...; kwargs...)
    x + length(args) + length(kwargs)
end
"""
msgs = lintstr(s)
@assert( isempty( msgs ) )
s = """
function f( x::Array{Number,1} )
    length(x)
end
"""
msgs = lintstr(s)
@assert( contains( msgs[1].message, "Type parameters in Julia are invariant" ) )
s = """
function f( x::Dict{Symbol,Number} )
    length(x)
end
"""
msgs = lintstr(s)
@assert( contains( msgs[1].message, "Type parameters in Julia are invariant" ) )
s = """
function f( x, y )
    using Base.Meta
    isexpr(x, :call) ? y : 0
end
"""
msgs = lintstr(s)
@assert( contains( msgs[1].message, "using is not allowed inside function" ) )
