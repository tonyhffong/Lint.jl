include("I474.jl")

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
@test occursin("while false block is unreachable", msgs[1].message)

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
@test occursin("typeof(x, msgs[1].message) == Int")
@test msgs[2].code == :I672
@test occursin("iteration works for a number but it may be a typo", msgs[2].message)
