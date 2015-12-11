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
@test msgs[1].code == 542
@test contains(msgs[1].message, "incompatible types (#1)")

# if it is not a staged function, it would have no lint message
s = """
@generated function f(x)
    :(x+y)
end
"""
msgs = lintstr(s)
@test msgs[1].code == 371
@test contains(msgs[1].message, "use of undeclared symbol")

s = """
@generated function f(args::Int...)
    @lintpragma("Info type args")
    x = args[1]
    @lintpragma("Info type x")
    :(show(x, args...))
end
"""
msgs = lintstr(s)
@test msgs[1].code == 271
@test contains(msgs[1].message, "typeof(args) == Tuple{Vararg{DataType}}")
@test msgs[2].code == 271
@test contains(msgs[2].message, "typeof(x) == DataType")
