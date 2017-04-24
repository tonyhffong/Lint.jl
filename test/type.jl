@testset "I393" begin
    s = """
    type MyType{Int64}
    end
    """
    msgs = lintstr(s)
    @test msgs[1].code == :I393
    @test msgs[1].variable == "Int64"
    @test contains(msgs[1].message, "using an existing type as type parameter name is probably a typo")

    @test messageset(lintstr("""
    type MyType{Int64} <: Float64
    end
    """)) == Set([:I393])
end

@testset "E513" begin
    msgs = lintstr("""
    type MyType{T<:Int}
    end
    """)
    @test messageset(msgs) == Set([:E513])
    @test msgs[1].variable == "T <: Int"
    @test contains(msgs[1].message, "leaf type as a type constraint makes no sense")

    msgs = lintstr("""
    type MyType{T<:Int, Int<:Real}
    end
    """)
    @test messageset(msgs) == Set([:E513, :E538])
    @test msgs[1].variable == "T <: Int"
    @test contains(msgs[1].message, "leaf type as a type constraint makes no sense")
    @test msgs[2].variable == "Int"
    @test contains(msgs[2].message, "known type in parametric data type, use {T<:...}")
end

@testset "E538" begin
    msgs = lintstr("""
    type MyType{Int<:Real}
    end
    """)
    @test messageset(msgs) == Set([:E538])
    @test contains(msgs[1].message, "known type in parametric data type, use {T<:...}")

    msgs = lintstr("""
    type SomeType
    end
    type MyType{SomeType<:Real}
    end
    """)
    @test messageset(msgs) == Set([:E538])
    @test contains(msgs[1].message, "known type in parametric data type, use {T<:...}")
end

# TODO: this inner constructor syntax is deprecated
@testset "Types" begin
    @test_broken isempty(lintstr("""
    type MyType{T}
        t::T
        MyType(x::T) = new(x)
    end
    """))

    @test_broken isempty(lintstr("""
    type MyType{T<:Integer}
        t::T
        MyType(x) = new(convert(T, x))
    end
    """))

    s = """
    type MyType <: Integer
        t::Int
        function MyTypo()
            new(1)
        end
    end
    """
    msgs = lintstr(s)
    @test_broken msgs[1].code == :E517
    @test_broken msgs[1].variable == "MyTypo"
    @test_broken contains(msgs[1].message, "constructor-like function name doesn't match type MyType")

    @test_broken isempty(lintstr("""
    type MyType{T}
        b::T
        MyType{S}(y::S) = new(convert(T,y))
    end
    """))
end

s = """
type MyType
    t::Int
    NotATypo() = 1
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
@compat abstract type SomeAbsType end
@compat abstract type SomeAbsNum <: Number end
@compat abstract type SomeAbsVec1{T} <: Array{T,1} end
@compat abstract type SomeAbsVec2{T} end
@compat primitive type MyBitsType 8 end

type MyType{T<:SomeAbsType}
    t::T
    MyType(x) = new(convert(T, x))
end
"""
@test_broken isempty(lintstr(s))

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
@test_broken msgs[1].code == :E611
@test_broken contains(msgs[1].message, "constructor doesn't seem to return the constructed object")

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
@test_broken isempty(msgs)

s = """
type MyType
    a
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I691
@test msgs[1].variable == "a"
@test contains(msgs[1].message, "a type is not given to the field which can be slow")

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
@test msgs[1].variable == "a"
@test contains(msgs[1].message, "array field has no dimension which can be slow")

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
@test contains(msgs[1].message, "use lintpragma macro inside type declaration")

s = """
@compat primitive type 8 a end
"""
msgs = lintstr(s)
@test msgs[1].code == :E101
@test contains(msgs[1].message, "this expression must be a Symbol")

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
@test contains(msgs[1].message, "anonymous function inside type definition")
@test_broken msgs[2].code == :E517
@test_broken msgs[2].variable == ""
@test_broken contains(msgs[2].message, "constructor-like function name doesn't match type MyType")

s = """
type MyType
    a::Int
    b::Int
    MyType(x) = new(x)
end
"""
msgs = lintstr(s)
@test_broken msgs[1].code == :I671
@test_broken contains(msgs[1].message, "new is provided with fewer arguments than fields")

@testset "Inner Constructors" begin
    @test isempty(lintstr("""
    type MyType{T}
        b::T
        (::Type{MyType}){T}(x::T) = new{T}(x)
    end
    """))

    @test isempty(lintstr("""
    type MyType{T}
        b::T
        (::Type{MyType}){T<:Integer}(x::T) = new{T}(x)
    end
    """))
end

s = """
type MyType
    a::Int
    b::Int
    MyType(x) = new(x, 0, 0)
end
"""
msgs = lintstr(s)
@test_broken msgs[1].code == :E435
@test_broken contains(msgs[1].message, "new is provided with more arguments than fields")

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

# TODO: this inner constructor syntax is deprecated
s = """
type MyType{T}
    b::T
    MyType(x::T) = new(x)
    MyType(x::Int) = MyType{T}(convert(T, x))
end
"""
msgs = lintstr(s)
@test_broken isempty(msgs)

s = """
type myType{T}
    b::T
    myType(x::T) = new(x)
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I771
@test contains(msgs[1].message, "type names should start with an upper case")
