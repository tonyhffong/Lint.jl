@testset "Tuple" begin

s = """
    (a,b) = (1,2,3)
"""
msgs = lintstr(s)
@test msgs[1].code == :W546
@test occursin("implicitly discarding values, 2 of 3 used", msgs[1].message)

s = """
    a, = (1,2,3)
"""
msgs = lintstr(s)
@test msgs[1].code == :W546
@test occursin("implicitly discarding values, 1 of 3 used", msgs[1].message)

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
@test occursin("RHS is a tuple, 3 of 2 variables used", msgs[1].message)

end
