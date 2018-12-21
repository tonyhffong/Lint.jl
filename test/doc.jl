s = """
@doc "this is a test" -> f() = 0
"""
msgs = lintstr(s)
@test isempty(msgs)

s = "@doc \"\"\"this is a test\"\"\" -> f() = 0"
msgs = lintstr(s)
@test isempty(msgs)

s = """
@doc "this is a test"
f() = 0
"""
msgs = lintstr(s)
@test msgs[1].code == :W443

s = """
@doc "this is a test" f() = 0
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
@doc \"\"\"
this is a test
\"\"\" f() = 0
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
@doc f
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
func(v) = v

\"\"\"
Documentation
\"\"\"
func(v)
"""
msgs = lintstr(s)
@test isempty(msgs)

# TODO: should we warn this documentation?
"""
type TestType
    "doc"
    a
end
"""
msgs = lintstr(s)
@test isempty(msgs)
