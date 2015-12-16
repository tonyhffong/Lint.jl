# give the macro linter a workout

s = """
macro r_str(pattern, flags...) Regex(pattern, flags...) end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
macro schedule(expr)
    expr = localize_vars(:(()->(\$expr)), false)
    :(enq_work(Task(\$(esc(expr)))))
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
@windows ? 1 : 2
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
@deprecate put put!
@deprecate readsfrom(cmd, args...)      open(cmd, "r", args...)
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
function f()
    @gensym x y z
    println(x)
    println(y)
    println(z)
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
macro mymacro(expr::Expr)
    expr
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
macro mymacro(expr::Int)
    expr
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E522
@test contains(msgs[1].message, "macro arguments can only be Symbol/Expr")

s = """
# using PyCall # we don't want to uncomment this
@pyimport seaborn as sns
@pyimport seaborn
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
@enum Z3_lbool Z3_L_FALSE = -1 Z3_L_UNDEF Z3_L_TRUE
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
macro ()
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E121
@test contains(msgs[1].message, "Lint does not understand")
