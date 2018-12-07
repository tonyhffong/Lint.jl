s = """
s = "a" + "b"
"""
msgs = lintstr(s)
@test msgs[1].code == :E422
@test occursin("string uses * to concatenate", msgs[1].message)

s = """
function f(x)
    Dict("a" + "b" => x)
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E422
@test occursin("string uses * to concatenate", msgs[1].message)

@test messageset(lintstr("""
s = String(1)
""")) == Set([:E539])

s = """
b = string(12)
s = "a" + b
"""
msgs = lintstr(s)
@test msgs[1].code == :E422
@test occursin("string uses * to concatenate", msgs[1].message)

s = """
function f()
    b = repeat(" ", 10)
    @lintpragma("Info type b")
    b
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test occursin("typeof(b, msgs[1].message) == $(Compat.String)")

u = """
안녕하세요 = "Hello World"

Hello
World
"""
msgs = lintstr(u)
@test msgs[1].code == :E321
@test msgs[1].variable == "Hello"
@test msgs[2].code == :E321
@test msgs[2].variable == "World"
