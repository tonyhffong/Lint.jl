s = """
function f(x)
    x + y
end
"""
msgs = lintstr(s)
@test length(msgs) == 1
@test msgs[1].code == 321
@test contains(msgs[1].message, "use of undeclared symbol")

s = """
function f(x)
    @lintpragma("Ignore use of undeclared variable y")
    x + y
end
"""
msgs = lintstr(s)
@test isempty(msgs)

# from @pao
s = """
function f()
    @lintpragma("Ignore use of undeclared variable aone")
    addOne() = @withOneVar aone (aone + 1)
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
function f(x)
    if x > 1
        local i = 1
        println(i)
        i = i + 1
    end
    i = 1
    i
end
"""
msgs = lintstr(s)
@test length(msgs) == 0

s = """
function f(x)
    try
        x > 1
        local i = 1
        println(i)
        i = i + 1
    end
    i = 1
    i
end
"""
msgs = lintstr(s)
@test msgs[1].code == 482
@test contains(msgs[1].message, "used in a local scope")

s = """
function f()
    :(x + y)
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
function f()
    open(readall, "tmp.txt")
end
"""
msgs = lintstr(s)
@test isempty(msgs)
