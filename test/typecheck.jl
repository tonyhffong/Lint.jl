@test isempty(lintstr("""
function f(x)
    local y::Float64 = 1
    x + y
end
"""))

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
@test_broken msgs[1].code == :W545
@test_broken occursin("previously used variable has apparent type", msgs[1].message)
@test msgs[end].code == :I271
@test_broken occursin("typeof(x, msgs[end].message) == Complex")

s = """
function f()
    x = rand()
    @lintpragma("Info type x")
    return x
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test occursin("typeof(x, msgs[1].message) == Float64")

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
@test occursin("typeof(x, msgs[1].message) == Array{Float64,1}")
@test msgs[2].code == :I271
@test occursin("typeof(y, msgs[2].message) == Array{Bool,2}")

s = """
function f()
    d = Dict{Symbol,Int}(:a=>1, :b=>2)
    x = d[:a]
    x = 1.0
    return x
end
"""
msgs = lintstr(s)
@test_broken msgs[1].code == :W545
@test_broken occursin("previously used variable has apparent type Int64, but " *
    "now assigned Float64", msgs[1].message)

s = """
function f(arr::Array{Any,1})
    x = arr[1]::Int64
    @lintpragma("Info type x")
    return x
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test occursin("typeof(x, msgs[1].message) == Int")

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
@test occursin("typeof(x, msgs[1].message) == Function")

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
@test occursin("typeof(x, msgs[1].message) == Module")

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
@test occursin("is of an immutable type Complex", msgs[1].message)

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
@test occursin("apparent type Type", msgs[1].message)
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
@test occursin("typeof(d, msgs[1].message) == Dict")

s = """
function f()
    d = Dict{Symbol,Any}(:a=>1, :b=>"")
    @lintpragma("Info type d")
    return d
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test occursin("typeof(d, msgs[1].message) == Dict")

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
@test occursin("typeof(a, msgs[1].message) == Array{Float64,3}")
@test occursin("typeof(c, msgs[2].message) == Array{Float64,3}")
@test occursin("typeof(d, msgs[3].message) == Array{Float64,2}")
@test occursin("typeof(e1, msgs[4].message) == Array{Float64,1}")

s = """
function f()
    a = Array(Float64, (1,2,3))
    s = size(a)
    @lintpragma("Info type s")
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test occursin("typeof(s, msgs[1].message) == Tuple{Int64,Int64,Int64}")

s = """
function f()
    a = Complex{Float64}[]
    @lintpragma("Info type a")
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test occursin("typeof(a, msgs[1].message) == Array{Complex{Float64},1}")

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
@test occursin("comparing apparently incompatible type", msgs[1].message)

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
