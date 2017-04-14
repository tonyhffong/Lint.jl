@testset "E321" begin
    msgs = lintstr("""
    function f(x)
        x + y
    end
    """)
    @test messageset(msgs) == Set([:E321])
    @test contains(msgs[1].message, "use of undeclared symbol")

    @test isempty(lintstr("""
    function f(x)
        @lintpragma("Ignore use of undeclared variable y")
        x + y
    end
    """))

    # from @pao
    @test_broken isempty(lintstr("""
    function f()
        @lintpragma("Ignore use of undeclared variable aone")
        addOne() = @withOneVar aone (aone + 1)
    end
    """))
end

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
@test_broken msgs[1].code == :I482
@test_broken contains(msgs[1].message, "used in a local scope")

s = """
function f()
    :(x + y)
end
"""
msgs = lintstr(s)
@test isempty(msgs)

if VERSION < v"0.5"
s = """
function f()
    open(readall, "tmp.txt")
end
"""
else
s = """
function f()
    open(readstring, "tmp.txt")
end
"""
end
msgs = lintstr(s)
@test isempty(msgs)
