s = """
function f(x)
    d = Dict{Symbol,Int}(:a=>1, :b=>2)
    for i in d
    end
    return x
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I474
@test contains(msgs[1].message, "iteration generates tuples, 1 of 2 variables used")

s = """
function f(x)
    while false
        println("test")
    end
    return x
end
"""
msgs = lintstr(s)
@test msgs[1].code == :W645
@test contains(msgs[1].message, "while false block is unreachable")

s = """
function f(x)
    arr = Array(Int, 1)
    for i in [1,2], j in arr
        println(i*j)
    end
    return x
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
function f(x)
    for i in (1,2,3)
        println(i)
    end
    return x
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
function f(x::Int)
    @lintpragma("Info type x")
    for i in x
        println(i)
    end
    return x
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test contains(msgs[1].message, "typeof(x) == Int")
@test msgs[2].code == :I672
@test contains(msgs[2].message, "iteration works for a number but it may be a typo")

s = """
function f(a::Array{Int,1})
    for i in enumerate(a)
        println(i)
    end
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I474
@test contains(msgs[1].message, "iteration generates tuples, 1 of 2 variables used")
