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
@test contains(msgs[1].message, "local variable")
@test contains(msgs[1].message, "shadows global variable")

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
@test contains(msgs[1].message, "expected assignment after \\\"const\\\"")

s = """
global 5
"""
msgs = lintstr(s)
@test msgs[1].code == :E134
@test contains(msgs[1].message, "unknown global pattern")

s = """
f() = x
x = 5
"""
msgs = lintstr(s)
@test_broken isempty(msgs)

s = """
x
x = 5
"""
msgs = lintstr(s)
@test msgs[1].code == :E321
@test contains(msgs[1].message, "use of undeclared symbol")

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
