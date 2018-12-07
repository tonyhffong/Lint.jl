@testset "Function Call" begin
s = """
function f(x; y = 1, z::Int = 4)
    println(z)
    x + y
end

f(1; y = 3)
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
function f{T}(x::T, y::T)
    a = Array{T, 1}()
    append!(a, [x, y])
    a
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
function f(::Type{Int}, x, y)
    x + y
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
function f(x, y, x)
    x + y
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E331
@test occursin("duplicate argument", msgs[1].message)

s = """
function f{Int64}(x::Int64, y::Int64)
    x + y
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E534
@test msgs[1].variable == "Int64"
@test occursin("introducing a new name for an implicit argument to the " *
    "function, use {T<:Int64}", msgs[1].message)

s = """
function f{T<:Int64}(x::T, y::T)
    x + y
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E513
@test msgs[1].variable == "T <: Int64"
@test occursin("leaf type as a type constraint makes no sense", msgs[1].message)

s = """
function f{Int<:Real}(x::Int, y::Int)
    x + y
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E536
@test occursin("use {T<:...} instead of a known type", msgs[1].message)

s = """
function f(x, args...)
    x + length(args)
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
function f(x, args..., bogus...)
    x + length(args) + length(bogus)
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E413
@test occursin("positional ellipsis ... can only be the last argument", msgs[1].message)

s = """
function f(x=1, y, args...)
    x + length(args) + y
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E411
@test occursin("non-default argument following default arguments", msgs[1].message)

s = """
function f(x, y; z, q=1)
    x + q + y
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E423
@test occursin("named keyword argument must have a default", msgs[1].message)

s = """
function f(x, y; args..., z=1)
    x + length(args) + y
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E412
@test occursin("named ellipsis ... can only be the last argument", msgs[1].message)

s = """
function f(x, args...; kwargs...)
    x + length(args) + length(kwargs)
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
function f(x::Array{Number,1})
    length(x)
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E533
@test occursin("type parameters are invariant, try f{T<:Number}(x::T, msgs[1].message)...")

s = """
function f(x::Dict{Symbol,Number})
    length(x)
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E533
@test occursin("type parameters are invariant, try f{T<:Number}(x::T, msgs[1].message)...")

s = """
function f(x; y = 1, z::Int = 0.1)
    x + y
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E516
@test occursin("type assertion and default", msgs[1].message)

s = """
function f(x; y = 1, z::Int = error("You must provide z"))
    x + y + z
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
g(x) = -x
function f(arr::Array)
    map(g, arr)
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
g(; x=0, y=1) = x+y
function f()
    d = Dict{Symbol, Int}(:x=>6, :y=>4)
    g(; d...)
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
function f{T}(a::Vector{T})
    n = size(a)
    tmp  = Array(T, n)
    tmp2 = zeros(T, 1)
    tmp3 = zeros(1, 2, 3)
    @lintpragma("Info type a")
    @lintpragma("Info type n")
    @lintpragma("Info type tmp")
    @lintpragma("Info type T")
    @lintpragma("Info type tmp2")
    @lintpragma("Info type tmp3")
    tmp
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test occursin("typeof(a, msgs[1].message) == Array")
@test msgs[2].code == :I271
@test occursin("typeof(n, msgs[2].message) == Tuple{Int64}")
if VERSION ≥ v"0.6-"
    @test msgs[3].code == :I271
    @test occursin("typeof(tmp, msgs[3].message) == Array")
end
@test msgs[4].code == :I271
@test_broken occursin("typeof(T, msgs[4].message) == Type")
if VERSION ≥ v"0.6-"
    @test msgs[5].code == :I271
    @test occursin("typeof(tmp2, msgs[5].message) == Array")
end
@test msgs[6].code == :I271
@test occursin("typeof(tmp3, msgs[6].message) == Array{Float64,3}")

s = """
function f(x)
    f = x
    f
end
"""
msgs = lintstr(s)
@test msgs[1].code == :W355
@test msgs[1].variable == "f"
@test occursin("conflicts with function name", msgs[1].message)

s = """
function f(x)
    local f = x
    f
end
"""
msgs = lintstr(s)
@test_broken isempty(msgs)

s = """
function f(x)
    x.somefunc(1)
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
function f(x=1)
    @lintpragma("Info type x")
    return x
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test occursin("typeof(x, msgs[1].message) == Int")

s = """
function f(x::Int8=Int8(1))
    @lintpragma("Info type x")
    return x
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test occursin("typeof(x, msgs[1].message) == Int8")

s = """
function f(c::Char)
    x = convert(Int, c)
    @lintpragma("Info type x")
    return x
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test occursin("typeof(x, msgs[1].message) == Int")

s = """
function f(args...; dict...)
    @lintpragma("Info type args")
    @lintpragma("Info type dict")
    length(args) + length(dict)
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test occursin("typeof(args, msgs[1].message) == Tuple")
@test msgs[2].code == :I271
@test occursin("typeof(dict, msgs[2].message) == Tuple")

s = """
function f(args::Float64...)
    @lintpragma("Info type args")
    length(args)
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test occursin("typeof(args, msgs[1].message) == Tuple{Vararg{Float64")

s = """
function f(args::Float64...)
    if args[1] == 1
        0
    else
        length(args)
    end
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
function f(x::Symbol)
    if x == "blah"
        0
    else
        1
    end
end
"""
msgs = lintstr(s)
@test msgs[1].code == :W542
@test occursin("comparing apparently incompatible type", msgs[1].message)

s = """
function f(X::Int)
    Y = X + 1
    return Y
end
"""
msgs = lintstr(s)
@test isempty(msgs)

@test_broken isempty(lintstr("""
function f1(a::Float64, b::Float64)
  function f2(x::Float64, a=a)
    x + a^2
  end
  return f2(b)
end
"""))

s="""
function f1(a::Float64; b=string(a))
    string(a) * b
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
function f end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
f(; x=1) = x
f(; 2)
"""
msgs = lintstr(s)
@test msgs[1].code == :E133
@test occursin("unknown keyword pattern", msgs[1].message)

s = """
function () end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
function foo end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
(==)(1, 1)
"""
msgs = lintstr(s)
@test isempty(msgs)

s="""
(==)(1)
"""
msgs = lintstr(s)
@test msgs[1].code == :E132
@test occursin("Lint does not understand argument", msgs[1].message)

s = """
(==)((1, 1)...)
"""
msgs = lintstr(s)
@test isempty(msgs)
end
