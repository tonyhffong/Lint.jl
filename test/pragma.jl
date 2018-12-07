s = """
function f(x)
    local a = 1
    local b = 2
    @lintpragma("Ignore unused a")
    return x+b
end
"""
msgs = lintstr(s)
@test_broken isempty(msgs)

s = """
function f(x)
    local a = 1
    local b = 2
    c = "a"
    @lintpragma("Ignore unused " * c)
    return x+b
end
"""
msgs = lintstr(s)
@test_broken length(msgs) == 2

# @lintpragma can also be used to generate messages
s = """
function f(x)
    local b = 2
    @lintpragma("Info type b")
    return x+b
end
"""
msgs = lintstr(s)
@test length(msgs) == 1
@test msgs[1].code == :I271
@test occursin("typeof(b, msgs[1].message) == Int")

s = """
function f(x)
    local b = 2
    @lintpragma("Warn type b")
    return x+b
end
"""
msgs = lintstr(s)
@test length(msgs) == 1
@test msgs[1].code == :W241
@test occursin("typeof(b, msgs[1].message) == Int")

s = """
function f(x)
    local b = 2
    @lintpragma("Error type b")
    return x+b
end
"""
msgs = lintstr(s)
@test length(msgs) == 1
@test msgs[1].code == :E221
@test occursin("typeof(b, msgs[1].message) == Int")

s = """
function f(x)
    local b = 2
    @lintpragma("Print type b")
    return x+b
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
function f(x)
    local b = 2
    @lintpragma("Print type b[1")
    return x+b
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E138
@test occursin("incomplete pragma expression", msgs[1].message)

s = """
function f(x)
    local b = 2
    @lintpragma("Info me my own reminder")
    return x+b
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test occursin("my own reminder", msgs[1].message)

s = """
function f(x)
    local b = 2
    @lintpragma("Info me " * string(b))
    return x+b
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E137
@test occursin("lintpragma must be called using only string literals", msgs[1].message)

s = """
function f(x)
    local a = 1
    local b = 2
    @lintpragma("Ignore unused a")
    return x+a+b
end
"""
msgs = lintstr(s)
@test_broken msgs[1].code == :I381
@test_broken msgs[1].variable == "Ignore unused a"
@test_broken occursin("unused lintpragma", msgs[1].message)

s = """
@lintpragma()
"""
msgs = lintstr(s)
@test msgs[1].code == :E137
@test occursin("lintpragma must be called using only string literals", msgs[1].message)
