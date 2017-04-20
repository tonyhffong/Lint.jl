@testset "Regressions" begin

# bug 137
@test isempty(lintstr("""
immutable Test137
   Test137(x) = x ? new() : error("constructor must be true")
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

# bug 166
@test isempty(lintstr("""
let x = :(type X end); x; end
"""))

# bug 164
@test messageset(lintstr("""
undefined()
""")) == Set([:E321])

# bug 215
@test isempty(lintstr("""
x = (rand(Bool) ? (1,) : (1.0,),)
for (i,) in x
    @show i
end
"""))

# bug 192
@test isempty(lintstr("""
type MyType end
@recipe function f(t::MyType)
    markersize --> 10
    seriestype := :scatter
    randn(10)
end
"""))

# bug 209
@test isempty(lintstr("""
function f{N}(::Array{Int,N})
    s = 0
    for j in 1:N
        s += j
    end
    s
end
"""))

# bug 187
@test isempty(lintstr("""
module Test187
import Compat.Iterators: flatten
export flatten
end
"""))

# bug 221
@test isempty(lintstr("""
@show quote
    include(string(VERSION))
end
"""))

# bug 219
@test isempty(lintstr("""
macro foo(x, y=100)
    quote
        \$(esc(x)) + \$(esc(y))
    end
end
"""))

end
