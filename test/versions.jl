s = """
if VERSION < v"0.4-" && VERSION > v"0.1"
    @lintpragma("Info version 0.3")
    @lintpragma("Info version 0.4")
else
    @lintpragma("Info version 0.3")
    @lintpragma("Info version 0.4")
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test contains(msgs[1].message, "Reachable by 0.3")
@test contains(msgs[2].message, "Unreachable by 0.4")
@test contains(msgs[3].message, "Unreachable by 0.3")
@test contains(msgs[4].message, "Reachable by 0.4")

s = """
test() = true
if VERSION < v"0.4-" && test()
    @lintpragma("Info version 0.3")
    @lintpragma("Info version 0.4.0-dev+1833")
else
    @lintpragma("Info version 0.3")
    @lintpragma("Info version 0.4.0-dev+1833")
end
"""
msgs = lintstr(s)
@test length(msgs) == 4
@test msgs[1].code == :I271
@test contains(msgs[1].message, "Reachable by 0.3")
@test contains(msgs[2].message, "Unreachable by 0.4")
@test contains(msgs[3].message, "Reachable by 0.3")
@test contains(msgs[4].message, "Reachable by 0.4") # we cannot prove unreachable

s = """
test() = true
if VERSION < v"0.4-" || test()
    @lintpragma("Info version 0.3")
    @lintpragma("Info version 0.4.0-dev+1833")
else
    @lintpragma("Info version 0.3")
    @lintpragma("Info version 0.4.0-dev+1833")
end
"""
msgs = lintstr(s)
@test length(msgs) == 4
@test msgs[1].code == :I271
@test contains(msgs[1].message, "Reachable by 0.3")
@test contains(msgs[2].message, "Reachable by 0.4")
@test contains(msgs[3].message, "Unreachable by 0.3")
@test contains(msgs[4].message, "Reachable by 0.4")

# testing `||`, should be rare
s = """
if VERSION >= v"0.4-" || VERSION < v"0.3"
    @lintpragma("Info version 0.3")
    @lintpragma("Info version 0.4.0-dev+1833")
else
    @lintpragma("Info version 0.3")
    @lintpragma("Info version 0.4.0-dev+1833")
end
"""
msgs = lintstr(s)
@test length(msgs) == 4
@test msgs[1].code == :I271
@test contains(msgs[1].message, "Unreachable by 0.3")
@test contains(msgs[2].message, "Reachable by 0.4")
@test contains(msgs[3].message, "Reachable by 0.3")
@test contains(msgs[4].message, "Unreachable by 0.4")

s = """
if !(VERSION >= v"0.4-")
    @lintpragma("Info version 0.3")
    @lintpragma("Info version 0.4.0-dev+1833")
else
    @lintpragma("Info version 0.3")
    @lintpragma("Info version 0.4.0-dev+1833")
end
"""
msgs = lintstr(s)
@test msgs[1].code == :I271
@test contains(msgs[1].message, "Reachable by 0.3")
@test contains(msgs[2].message, "Unreachable by 0.4")
@test contains(msgs[3].message, "Unreachable by 0.3")
@test contains(msgs[4].message, "Reachable by 0.4")
