s = """
type MyType{T}
    t::T
    MyType( x::T ) = new( x )
end
"""
msgs = lintstr(s)
@assert( isempty( msgs ) )

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
s = """
type MyType{T<:Int}
end
"""
msgs = lintstr(s)
@assert( contains( msgs[1].message, "leaf type" ) )
s = """
type MyType{T<:Int, Int<:Real}
end
"""
msgs = lintstr(s)
@assert( contains( msgs[1].message, "leaf type" ) )
@assert( contains( msgs[2].message, "parametric data type" ) )
s = """
type MyType{Int<:Real}
end
"""
msgs = lintstr(s)
@assert( contains( msgs[1].message, "instead of a known type" ) )
s = """
type SomeType
end
type MyType{SomeType<:Real}
end
"""
msgs = lintstr(s)
@assert( contains( msgs[1].message, "instead of a known type" ) )
s = """
type MyType{T<:Integer}
    t::T
    MyType( x ) = new( convert( T, x ) )
end
"""
msgs = lintstr(s)
@assert( isempty( msgs ) )
s = """
type MyType <: Integer
    t::Int
    function MyTypo()
        new( 1 )
    end
end
"""
msgs = lintstr(s)
@assert( contains( msgs[1].message, "Constructor-like function" ) )
s = """
type MyType
    t::Int
    NotATypo() = 1
end
"""
msgs = lintstr(s)
@assert( isempty( msgs ) )
s = """
typealias T Int64
typealias SharedVector{T} SharedArray{T,1}

type MyType{T}
    t::T
    MyType( x ) = new( convert( T, x ) )
end
"""
msgs = lintstr(s)
@assert( contains( msgs[1].message, "unrelated to the type" ) )
s = """
abstract SomeAbsType
abstract SomeAbsNum <: Number
abstract SomeAbsVec1{T} <: Array{T,1}
abstract SomeAbsVec2{T}
bitstype 8 MyBitsType

type MyType{T<:SomeAbsType}
    t::T
    MyType( x ) = new( convert( T, x ) )
end
"""
msgs = lintstr(s)
@assert( isempty( msgs ) )
s = """
type MyType{T<:Integer}
    t::T
    function MyType( x, someFunc::Function )
        o = new( convert( T, x ) )
        finalizer( o, someFunc ) # forgot to return o
    end
end
"""
msgs = lintstr(s)
@assert( contains( msgs[1].message, "Constructor doesn't seem to return the constructed object"))
s = """
type MyType{T<:Integer}
    t::T
    function MyType( x, someFunc::Function )
        o = new( convert( T, x ) )
        finalizer( o, someFunc ) # didn't forget to return o
        return o
    end
end
"""
msgs = lintstr(s)
@assert( isempty( msgs ) )
s = """
type MyType
    a
end
"""
msgs = lintstr(s)
@assert( contains( msgs[1].message, "A type is not given to the field a" ) )
s = """
type MyType
    @lintpragma( "Ignore untyped field a")
    a
end
"""
msgs = lintstr(s)
@assert( isempty( msgs ) )
s = """
type MyType
    a::Array{Float64}
end
"""
msgs = lintstr(s)
@assert( contains( msgs[1].message, "Array field a has no dimension" ) )
s = """
type MyType
    @lintpragma( "Ignore dimensionless array field a" )
    a::Array{Float64}
end
"""
msgs = lintstr(s)
@assert( isempty( msgs ) )
s = """
type MyType
    lintpragma( "Ignore dimensionless array field a" )
    a::Array{Float64}
end
"""
msgs = lintstr(s)
@assert( contains( msgs[1].message, "Use @lintpragma macro inside type declaration" ) )
s = """
bitstype a 8
"""
msgs = lintstr(s)
@assert( contains( msgs[1].message, "bitstype needs its 2nd argument to be a new type symbol" ) )

s = """
type MyType
    a::Int
    b::Int
    MyType( x::Int,y::Int ) = new(x,y)
    MyType( x::Int ) = MyType( x, 0 )
end
"""
msgs = lintstr(s)
@assert( isempty( msgs ) )
s = """
type MyType
    a::Int
    b::Int
    function( x )
        new(x)
    end
end
"""
msgs = lintstr(s)
@assert( contains( msgs[1].message, "What is an anonymous function doing inside a type definition" ) )
@assert( contains( msgs[2].message, "Constructor-like function" ) )
s = """
type MyType
    a::Int
    b::Int
    MyType( x )= new(x)
end
"""
msgs = lintstr(s)
@assert( contains( msgs[1].message, "new is not provided with the correct number of arguments" ) )

s = """
type MyType{T}
    b::T
    MyType{T}(x::T) = new( T )
end
"""
msgs = lintstr(s)
@assert( contains( msgs[1].message, "Parametric constructors (with curly brackets) should not be inner constructors." ) )
