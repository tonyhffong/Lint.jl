@assert [[1;2];[3;4]] == [1;2;3;4]
s = """
r = [[1;2];[3;4]]
"""
msgs = lintstr(s)
@test msgs[1].code == :W444
@test contains(msgs[1].message, "nested vcat is treated as a 1-dimensional array")

s = """
r = [[1,2],[3,4]]
"""
msgs = lintstr(s)
@test msgs[1].code == :E424
@test contains(msgs[1].message, "nested vect is treated as a 1-dimensional array. Use " *
    "[a;b] instead")

@assert [[1 2] [3 4]] == [1 2 3 4]
s = """
r = [[1 2]  [3 4]]
"""
msgs = lintstr(s)
@test msgs[1].code == :W445
@test contains(msgs[1].message, "nested hcat is treated as a 1-row horizontal array of " *
    "dim=2")

s = """
x = Any[[1,2],[7,8]]
y = Array[[1,2],[3,4]]
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
function f(x::Array{Float64,2})
    y = x[1, 2, 3]
    y
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E436
@test contains(msgs[1].message, "more indices than dimensions")

s = """
function f(x::Array{Float64,2})
    x[1, 2, 3]
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E436
@test contains(msgs[1].message, "more indices than dimensions")

s = """
function f(x::Array{Float64,2})
    y = x[Colon(), 1]
    for i in y
        println(i)
    end
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
function f(x::Array{Float64,2})
    y = x[1,1]
    @lintpragma("Info type y")
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test contains(msgs[1].message, "typeof(y) == Float64")

s = """
function f(t)
    x1 = zeros(1, 2)
    x2 = zeros(Int64, 2, 2)
    x3 = zeros(t, 2, 2)
    x4 = zeros(x1)
    @lintpragma("Info type x1")
    @lintpragma("Info type x2")
    @lintpragma("Info type x3")
    @lintpragma("Info type x4")
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test contains(msgs[1].message, "typeof(x1) == Array{Float64,2}")
@test msgs[2].code == :I271
@test contains(msgs[2].message, "typeof(x2) == Array{Int64,2}")
@test msgs[3].code == :I271
@test contains(msgs[3].message, "typeof(x3) == Array{T,N}")
@test msgs[4].code == :I271
@test contains(msgs[4].message, "typeof(x4) == Array{Float64,2}")

# more array function
s = """
function f(t::Array{Int64,2}, m, n)
    x1 = slicedim(t, 2, 1)
    x2 = reshape(t, 1)
    x3 = reshape(t, (1,2))
    x4 = reshape(m, (1,2))
    x5 = reshape(t, n)
    x6 = reshape(t, 1, 2)
    x7 = t'
    @lintpragma("Info type x1")
    @lintpragma("Info type x2")
    @lintpragma("Info type x3")
    @lintpragma("Info type x4")
    @lintpragma("Info type x5")
    @lintpragma("Info type x6")
    @lintpragma("Info type x7")
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test contains(msgs[1].message, "typeof(x1) == Array{Int64,2}")
@test msgs[2].code == :I271
@test contains(msgs[2].message, "typeof(x2) == Array{Int64,1}")
@test msgs[3].code == :I271
@test contains(msgs[3].message, "typeof(x3) == Array{Int64,2}")
@test msgs[4].code == :I271
@test contains(msgs[4].message, "typeof(x4) == Any")
@test msgs[5].code == :I271
@test contains(msgs[5].message, "typeof(x5) == Array{Int64,N}")
@test msgs[6].code == :I271
@test contains(msgs[6].message, "typeof(x6) == Array{Int64,2}")
@test msgs[7].code == :I271
@test contains(msgs[7].message, "typeof(x7) == Array{Int64,2}")

s = """
function f(a::Array{Float64})
    x = a[1,2]
    @lintpragma("Info type x")
    return x
end
"""
msgs = lintstr(s)
# it could be Float64, or it could be an array still!
@test msgs[1].code == :I271
@test contains(msgs[1].message, "typeof(x) == Any")

s = """
s = utf8("abcdef")
s = s[chr2ind(s,2) :end]
"""
msgs = lintstr(s)
@test msgs[1].code == :I681
@test contains(msgs[1].message, "ambiguity of :end as a symbol vs as part of a range")

s = """
s = utf8("abcdef")
sndlast = s[end -1]
"""
msgs = lintstr(s)
@test msgs[1].code == :I682
@test contains(msgs[1].message, "ambiguity of `[end -n]` as a matrix row vs index [end-n]")

s = """
function f()
    x1 = zeros(100, 100)
    x2 = Array(Float64, (100, 100))
    x1[1, 1]
    x2[1, 1]
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
function f(y::Array{Float64, 3}, x1::Int64)
    reshape(y[Colon(), x1, Colon()]', size(y, 1), size(y, 3)')
end
"""
msgs = lintstr(s)
@test isempty(msgs)
