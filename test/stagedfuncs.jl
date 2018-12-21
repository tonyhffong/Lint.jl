s = """
@generated function f(a,b)
    if a == 1
        :(b)
    elseif b == Int
        :(a)
    else
        :(0)
    end
end
"""

msgs = lintstr(s)
@test msgs[1].code == :W542
@test occursin("incompatible types (#1, msgs[1].message)")

# if it is not a staged function, it would have no lint message
s = """
@generated function f(x)
    :(x+y)
end
"""
msgs = lintstr(s)
@test_broken msgs[1].code == :I371
@test_broken occursin("use of undeclared symbol", msgs[1].message)

s = """
@generated function f(args::Int...)
    @lintpragma("Info type args")
    x = args[1]
    @lintpragma("Info type x")
    :(show(x, args...))
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test occursin("typeof(args, msgs[1].message) == Tuple{Vararg{Type")
@test msgs[2].code == :I271
@test occursin("typeof(x, msgs[2].message) == ")
