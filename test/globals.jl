@testset "Globals" begin

@test isempty(lintstr("""
y=1
function f(x)
    x + y
end
"""))

@test isempty(lintstr("""
y = 1
function f(x)
    global y = 2
    x + y
end
"""))

msgs = lintstr("""
yyyyyy = 1
function f(x)
    yyyyyy = 2
    x + yyyyyy
end
""")
@test msgs[1].code == :I341
@test msgs[1].variable == "yyyyyy"
@test occursin("local variable", msgs[1].message)
@test occursin("shadows global variable", msgs[1].message)

s = """
y = 1
function f(x)
    y = 2
    x + y
end
"""
msgs = lintstr(s)
@test_broken isempty(msgs) # short names are grandfathered to be ok

s = """
const y = 1
function f(x)
    y = 2
    x + y
end
"""
msgs = lintstr(s)
@test_broken isempty(msgs) # short names are grandfathered to be ok

s = """
const y
function f(x)
    y = 2
    x + y
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E111
@test occursin("expected assignment after \\\"const\\\"", msgs[1].message)

s = """
global 5
"""
msgs = lintstr(s)
@test msgs[1].code == :E134
@test occursin("unknown global pattern", msgs[1].message)

s = """
f() = x
x = 5
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
x
x = 5
"""
msgs = lintstr(s)
@test msgs[1].code == :E321
@test occursin("use of undeclared symbol", msgs[1].message)

# Test gloabls defined in other files
# File in package src
msgs = lintfile("FakePackage/src/subfolder2/file2.jl")
@test_broken isempty(msgs)
# File in package test
msgs = lintfile("FakePackage/test/file2.jl")
@test_broken isempty(msgs)
# File in base julia
msgs = lintfile("FakeJulia/base/file2.jl")
@test_broken isempty(msgs)

msgs = lintfile("filename","something")
@test msgs[1].code == :E321
end
