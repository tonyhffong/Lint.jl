s = """
s = "a" + "b"
"""
msgs = lintstr(s)
@test msgs[1].code == :E422
@test contains(msgs[1].message, "string uses * to concatenate")

s = """
function f(x)
    Dict("a" + "b" => x)
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E422
@test contains(msgs[1].message, "string uses * to concatenate")

if VERSION < v"0.5-"
    s = """
    s = String(1)
    """
    msgs = lintstr(s)
    @test msgs[1].code == :E537
    @test contains(msgs[1].message,
        "String constructor does not exist in v0.4; use string() instead")
end

s = """
b = string(12)
s = "a" + b
"""
msgs = lintstr(s)
@test msgs[1].code == :E422
@test contains(msgs[1].message, "string uses * to concatenate")

s = """
function f()
    b = repeat(" ", 10)
    @lintpragma("Info type b")
    b
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test contains(msgs[1].message, "typeof(b) == $(Compat.ASCIIString)")

s = """
function f()
    b = repeat(" ", 10)
    b[:start]
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E519
@test msgs[1].variable == ":start"
@test contains(msgs[1].message, "string[] expects Integer, provided Symbol")

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
