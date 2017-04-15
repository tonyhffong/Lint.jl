@testset "Macros" begin

s = """
macro rr_str(pattern, flags...) Regex(pattern, flags...) end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
localize_vars(foo, bar) = (foo, bar)
macro myschedule(expr)
    expr = localize_vars(:(()->(\$expr)), false)
    :(enq_work(Task(\$(esc(expr)))))
end
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

#= (issues #140)
s = """
macro mymacro(expr::Int)
    expr
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E522
@test contains(msgs[1].message, "macro arguments can only be Symbol/Expr")
=#

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

@testset "E141" begin
    s = """
    macro ()
    end
    """
    msgs = lintstr(s)
    @test_broken msgs[1].code == :E141
    @test_broken contains(msgs[1].message, "invalid macro syntax")
end

s = """
macro foo()
    println("foo")
end
"""
msgs = lintstr(s)
@test isempty(msgs)

@testset "E437" begin
    @test messageset(lintstr("@compat()")) == Set([:E437])
    @test messageset(lintstr("@compat(1, 2)")) == Set([:E437])
end

end
