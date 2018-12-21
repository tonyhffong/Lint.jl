@testset "Lambdas" begin
s = """
function f()
    local x = 1
    g = x-> x+1
    g(x)
end
"""
msgs = lintstr(s)

@test_broken msgs[1].code == :W352
@test_broken occursin("lambda argument conflicts with a local variable", msgs[1].message)

s = """
function f(x)
    map(x-> x+1, x)
end
"""
msgs = lintstr(s)
@test_broken msgs[1].code == :W353
@test_broken occursin("lambda argument conflicts with an argument", msgs[1].message)

s = """
x = 1
function f()
    g = x-> x+1
    return g
end
"""
msgs = lintstr(s)
@test_broken msgs[1].code == :W354
@test_broken occursin("lambda argument conflicts with an declared global", msgs[1].message)

s = """
function f()
    @lintpragma("Ignore unused y")
    @lintpragma("Ignore unused z")
    @lintpragma("Ignore unused args")
    g = (x, y::Int, z::Float64=0.0, args...)-> x+1
end
"""
msgs = lintstr(s)
@test_broken isempty(msgs)

s = """
ntuple(_->0, 4)
"""
msgs = lintstr(s)
@test isempty(msgs)
end
