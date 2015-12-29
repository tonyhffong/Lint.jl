s = """
s = "a" + "b"
"""
msgs = lintstr(s)
@test msgs[1].code == :E422
@test contains(msgs[1].message, "string uses * to concat")

s = """
function f(x)
    Dict("a" + "b" => x)
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E422
@test contains(msgs[1].message, "string uses * to concat")

s = """
s = String(1)
"""
msgs = lintstr(s)
@test msgs[1].code == :E537
@test contains(msgs[1].message, "you want string")

s = """
b = string(12)
s = "a" + b
"""
msgs = lintstr(s)
@test msgs[1].code == :E422
@test contains(msgs[1].message, "string uses * to concat")

s = """
function f()
    b = repeat(" ", 10)
    @lintpragma("Info type b")
    b
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test contains(msgs[1].message, "typeof(b) == ASCIIString")

s = """
function f()
    b = repeat(" ", 10)
    b[:start]
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E519
@test contains(msgs[1].message, "string[] expects Integer, provided Symbol")
