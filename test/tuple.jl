@testset "Tuple" begin

s = """
    (a,b) = (1,2,3)
"""
msgs = lintstr(s)
@test msgs[1].code == :W546
@test contains(msgs[1].message, "implicitly discarding values, 2 of 3 used")

s = """
    a, = (1,2,3)
"""
msgs = lintstr(s)
@test msgs[1].code == :W546
@test contains(msgs[1].message, "implicitly discarding values, 1 of 3 used")

@test isempty(lintstr("a = (1, 2, 3)"))

s = """
function f()
    (a,b,c) = (1,2,3)
    return (b,c,a)
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
    (a,b,c) = (1,2)
"""
msgs = lintstr(s)
@test msgs[1].code == :E418
@test contains(msgs[1].message, "RHS is a tuple, 3 of 2 variables used")

end
