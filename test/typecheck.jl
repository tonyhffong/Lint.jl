s = """
function f(x)
    local y::Float64 = 1
    x + y
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I572
@test contains(msgs[1].message, "but assign a value of")

s = """
function f(c::Char)
    x = Int8(c)
    x = Int16(x)
    x = Int32(x)
    x = Int64(x)
    x = Int(x)
    x = Rational(x)
    x = float(x)
    x = Complex(x)
    @lintpragma("Info type x")
    return x
end
"""
msgs = lintstr(s)
@test msgs[1].code == :W545
@test contains(msgs[1].message, "previously used variable has apparent type")
@test msgs[end].code == :I271
@test contains(msgs[end].message, "typeof(x) == Complex")

s = """
function f()
    x = rand()
    @lintpragma("Info type x")
    return x
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test contains(msgs[1].message, "typeof(x) == Float64")

s = """
function f()
    x = rand(3)
    y = rand(Bool, 5, 5)
    @lintpragma("Info type x")
    @lintpragma("Info type y")
    return x, y
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test contains(msgs[1].message, "typeof(x) == Array{Float64,1}")
@test msgs[2].code == :I271
@test contains(msgs[2].message, "typeof(y) == Array{Bool,2}")

s = """
function f()
    d = Dict{Symbol,Int}(:a=>1, :b=>2)
    x = d[:a]
    x = 1.0
    return x
end
"""
msgs = lintstr(s)
@test msgs[1].code == :W545
@test contains(msgs[1].message, "previously used variable has apparent type Int64, but " *
    "now assigned Float64")

s = """
function f(arr::Array{Any,1})
    x = arr[1]::Int64
    @lintpragma("Info type x")
    return x
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test contains(msgs[1].message, "typeof(x) == Int")

s = """
g(x) = x

function f()
    x = g
    @lintpragma("Info type x")
    return x
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test contains(msgs[1].message, "typeof(x) == Function")

s = """
module MyModule
end

function f()
    x = MyModule
    @lintpragma("Info type x")
    return x
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test contains(msgs[1].message, "typeof(x) == Module")

s = """
function f()
    z = Complex(1.0, 1.0)
    z.re = 2.0
    z
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E525
@test msgs[1].variable == "z"
@test contains(msgs[1].message, "is of an immutable type Complex")

#= TODO: the warning here should be on a = Array{Int32, n}, not the E521
s = """
n = 32
a = Array{Int32, n} # bug is here
for i in 1:n
    a[i] = i
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E521
@test msgs[1].variable == "a"
@test contains(msgs[1].message, "apparent type Type")
=#

include("E522.jl")

s = """
function f()
    d = Dict(:a=>1, :b=>"")
    @lintpragma("Info type d")
    return d
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test contains(msgs[1].message, "typeof(d) == Dict")

s = """
function f()
    d = Dict{Symbol,Any}(:a=>1, :b=>"")
    @lintpragma("Info type d")
    return d
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test contains(msgs[1].message, "typeof(d) == Dict")

s = """
function f(n)
    a = Array(Float64, (1,2,3))
    @lintpragma("Info type a")
    c = Array(Float64, 1,2,3)
    @lintpragma("Info type c")
    d = zeros(Float64, (1,2))
    @lintpragma("Info type d")
    e1 = zeros(2)
    @lintpragma("Info type e1")
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test contains(msgs[1].message, "typeof(a) == Array{Float64,3}")
@test contains(msgs[2].message, "typeof(c) == Array{Float64,3}")
@test contains(msgs[3].message, "typeof(d) == Array{Float64,2}")
@test contains(msgs[4].message, "typeof(e1) == Array{Float64,1}")

s = """
function f()
    a = Array(Float64, (1,2,3))
    s = size(a)
    @lintpragma("Info type s")
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test contains(msgs[1].message, "typeof(s) == Tuple{Int64,Int64,Int64}")

s = """
function f()
    a = Complex{Float64}[]
    @lintpragma("Info type a")
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test contains(msgs[1].message, "typeof(a) == Array{Complex{Float64},1}")

s = """
    Complex(0.0,0.0) == 0
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
    Complex(1.0,0.0) > 0
"""
msgs = lintstr(s)
@test msgs[1].code == :W542
@test contains(msgs[1].message, "comparing apparently incompatible type")

s = """
s = Union(Int,Double)
"""
msgs = lintstr(s)
@test msgs[1].code == :W441

s = """
a = 1.0
a /= 2
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
function f(x::ANY...)
   x[1]
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
function typed_hcat(A::AbstractVecOrMat...)
   A[1]
end
"""
msgs = lintstr(s)
@test isempty(msgs)

@testset "E539" begin
    # assigning error to a variable
    @test messageset(lintstr("""
    x = throw(ArgumentError("error!"))
    """)) == Set([:E539])

    @test messageset(lintstr("""
    x = 1 + "x"
    """)) == Set([:E422, :E539])

    @test isempty(lintstr("""
    x = 1 + 1 == 2 ? "OK" : error("problem")
    """))

    @test messageset(lintstr("""
    x, y = error()
    """)) == Set([:E539])

    @test messageset(lintstr("""
    κ = sqrt("x")
    """)) == Set([:E539])
end
