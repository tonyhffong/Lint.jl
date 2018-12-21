@testset "If" begin
s = """
wrap(pos::Int, len::Int) = true ? 1 : (pos > len ? len : pos)
"""
msgs = lintstr(s)
@test length(msgs) == 3
@test msgs[1].code == :W643
@test occursin("false branch is unreachable", msgs[1].message)
@test msgs[2].code == :I340
@test occursin("unused local variable", msgs[2].message)
@test msgs[3].code == :I340
@test occursin("unused local variable", msgs[3].message)

s = """
wrap(pos::Int, len::Int) = false ? 1 : (pos > len ? len : pos)
"""
msgs = lintstr(s)
@test length(msgs) == 1
@test msgs[1].code == :W642
@test occursin("true branch is unreachable", msgs[1].message)
@test Lint.line(msgs[1]) == 1

s = """
f(x) = (x=1) ? 1 : 2 # clearly not what we want
"""
msgs = lintstr(s)
@test msgs[1].code == :I472
@test occursin("assignment in the if-predicate clause", msgs[1].message)

s = """
f(x) = ifelse(length(x), 1 , 2) # clearly not what we want
"""
msgs = lintstr(s)
@test msgs[1].code == :E431
@test occursin("use of length(, msgs[1].message) in a Boolean context, use isempty()")

s = """
f(x,y) = (0 <= x < y = 6) ? 1 : 2 # clearly not what we want
"""
msgs = lintstr(s)
@test msgs[1].code == :I472
@test occursin("assignment in the if-predicate clause", msgs[1].message)

s = """
function f()
    if true
        println("hello")
    end
end
"""
msgs = lintstr(s)
@test msgs[1].code == :W644
@test occursin("redundant if-true statement", msgs[1].message)

s = """
function f()
    v::Array{Int,1} = [1,2,3]
    if length(v)
        println("hello")
    end
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E431
@test occursin("use of length(, msgs[1].message) in a Boolean context, use isempty()")

s = """
function f(b::Bool, x::Int, y::Int)
    a = b ? x : y
    @lintpragma("Info type a")
    a
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test occursin("typeof(a, msgs[1].message) == Int")

s = """
function f(b::Bool, x::Int, y::Any)
    a = b ? x : y
    @lintpragma("Info type a")
    a
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test occursin("typeof(a, msgs[1].message) == Any")

s = """
function f()
    if :a && !:b
        1
    else
        2
    end
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E512
@test msgs[1].variable == ":a"
@test occursin("Lint doesn't understand in a boolean context", msgs[1].message)
@test msgs[2].code == :E512
@test msgs[2].variable == ":b"
@test occursin("Lint doesn't understand in a boolean context", msgs[2].message)

s = """
function f(a, b)
    if a == 1 # MISSING && or ||
        b == 2
        1
    else
        2
    end
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I571
@test occursin("the 1st statement under the true-branch is a boolean expression", msgs[1].message)

s = """
function f(a, b)
    if a == 1 # MISSING && or ||
        !(b < 2)
        1
    else
        2
    end
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I571
@test occursin("the 1st statement under the true-branch is a boolean expression", msgs[1].message)

s = """
function f(a, b)
    if a == 1 (b < 2) || error("b needs to be < 2")
        1
    else
        2
    end
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
function f(a, b)
    if a == 1 (b < 2) || return 3
        1
    else
        2
    end
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
1==1 && true
true && 1==1
1==1 || true || 1==1
1==1 || 1==1 || true
true || 1==1 || 1==1
"""
msgs = lintstr(s)
@test isempty(msgs)

# issue #149: it's not always safe to include modules
s = """
if 1 == 0  # suppress if false warning
    using FakeModule149
end
"""
msgs = lintstr(s)
@test isempty(msgs)
end
