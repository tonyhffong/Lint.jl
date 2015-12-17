s = """
type MyType{T}
    t::T
    MyType(x::T) = new(x)
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
type MyType{Int64}
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E535
@test contains(msgs[1].message, "unrelated to the type")

s = """
type MyType{Int64} <: Float64
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E535
@test contains(msgs[1].message, "unrelated to the type")

s = """
type MyType{T<:Int}
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E514
@test contains(msgs[1].message, "leaf type")

s = """
type MyType{T<:Int, Int<:Real}
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E514
@test contains(msgs[1].message, "leaf type")
@test msgs[2].code == :E538
@test contains(msgs[2].message, "parametric data type")

s = """
type MyType{Int<:Real}
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E538
@test contains(msgs[1].message, "instead of a known type")

s = """
type SomeType
end
type MyType{SomeType<:Real}
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E538
@test contains(msgs[1].message, "instead of a known type")

s = """
type MyType{T<:Integer}
    t::T
    MyType(x) = new(convert(T, x))
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
type MyType <: Integer
    t::Int
    function MyTypo()
        new(1)
    end
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E517
@test contains(msgs[1].message, "constructor-like function")

s = """
type MyType
    t::Int
    NotATypo() = 1
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
typealias TT Int64
typealias SharedVector{TT} SharedArray{TT,1}

type MyType{TT}
    t::TT
    MyType(x) = new(convert(TT, x))
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E535
@test contains(msgs[1].message, "unrelated to the type")

s = """
abstract SomeAbsType
abstract SomeAbsNum <: Number
abstract SomeAbsVec1{T} <: Array{T,1}
abstract SomeAbsVec2{T}
bitstype 8 MyBitsType

type MyType{T<:SomeAbsType}
    t::T
    MyType(x) = new(convert(T, x))
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
type MyType{T<:Integer}
    t::T
    function MyType(x, someFunc::Function)
        o = new(convert(T, x))
        finalizer(o, someFunc) # forgot to return o
    end
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E611
@test contains(msgs[1].message, "constructor doesn't seem to return the constructed object")

s = """
type MyType{T<:Integer}
    t::T
    function MyType(x, someFunc::Function)
        o = new(convert(T, x))
        finalizer(o, someFunc) # didn't forget to return o
        return o
    end
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
type MyType
    a
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I691
@test contains(msgs[1].message, "a type is not given to the field a")

s = """
type MyType
    @lintpragma("Ignore untyped field a")
    a
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
type MyType
    a::Array{Float64}
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I692
@test contains(msgs[1].message, "array field a has no dimension")

s = """
type MyType
    @lintpragma("Ignore dimensionless array field a")
    a::Array{Float64}
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
type MyType
    lintpragma("Ignore dimensionless array field a")
    a::Array{Float64}
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E425
@test contains(msgs[1].message, "use @lintpragma macro inside type declaration")

s = """
bitstype a 8
"""
msgs = lintstr(s)
@test msgs[1].code == :E524
@test contains(msgs[1].message, "bitstype needs its 2nd argument to be a new type symbol")

s = """
type MyType
    a::Int
    b::Int
    MyType(x::Int,y::Int) = new(x,y)
    MyType(x::Int) = MyType(x, 0)
    function MyType()
        v = new(0, 0)
        v[2] = convert(Int, rand()* 5.0) # assume we'd define setindex! somewhere
        v
    end
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
type MyType
    a::Int
    b::Int
    function(x)
        new(x)
    end
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E417
@test contains(msgs[1].message, "what is an anonymous function doing inside a type definition")
@test msgs[2].code == :E517
@test contains(msgs[2].message, "constructor-like function")

s = """
type MyType
    a::Int
    b::Int
    MyType(x) = new(x)
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I671
@test contains(msgs[1].message, "new is provided with fewer arguments than fields")

s = """
type MyType{T}
    b::T
    MyType{T}(x::T) = new(x)
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E523
@test contains(msgs[1].message, "constructor parameter (within curly brackets)")

s = """
type MyType{T}
    b::T
    MyType{T<:Integer}(x::T) = new(x)
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E523
@test contains(msgs[1].message, "constructor parameter (within curly brackets)")

s = """
type MyType{T}
    b::T
    MyType{S}(y::S) = new(convert(T,y))
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
type MyType
    a::Int
    b::Int
    MyType(x) = new(x, 0, 0)
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E435
@test contains(msgs[1].message, "new is provided with more arguments than fields")

s = """
type MyType
    a::Int
    b::Int
    MyType() = new()
end
"""
msgs = lintstr(s)
@test isempty(msgs) # ok

s = """
type MyType
    a::Int
    b::Int
    function MyType(x)
        @lintpragma("Ignore short new argument")
        new(x)
    end
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
type MyType{T}
    b::T
    MyType(x::T) = new(x)
    MyType(x::Int) = MyType{T}(convert(T, x))
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
type myType{T}
    b::T
    myType(x::T) = new(x)
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I771
@test contains(msgs[1].message, "Julia style recommends type names start with an upper case")
