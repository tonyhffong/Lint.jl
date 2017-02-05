@testset "Regressions" begin

# bug 137
@test isempty(lintstr("""
immutable Test
   Test(x) = x ? new() : error("constructor must be true")
end
"""))

# bug 88
@test isempty(lintstr("""
F = Float64
Complex{F}

type MyType{T}
a::T
end

f{A}(z::Complex{A}) = z
g{B}(z::MyType{B}) = z
"""))

# bug 122
@test isempty(lintstr("""
foo{S<:AbstractString}(args::Array{S}=ARGS) = typeof(args)
"""))

# bug 56, 84
@test isempty(lintstr("""
foo!(args::AbstractArray) = (args.x = 1)
"""))

@test messageset(lintstr("""
foo!(args::Complex) = (args.re = 1)
""")) == Set([:E525])

# bug 171
@test isempty(lintstr("""
using Base.iteratorsize
"""))

# bug 135
@test isempty(lintstr("""
import Base: ==, hash, length, size, -, +, ./, norm, dot, angle, cross, vec,
             any, print, show, parse
"""))

# bug 81
@test isempty(lintstr("""
A = [[1, 2], [3, 4]]
println(A[1][1])
"""))

# bug 180
@test messageset(lintstr("""
x, y = error()
""")) == Set([:E539])

end
