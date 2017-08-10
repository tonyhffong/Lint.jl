s = """
import Base: show
import Base.Math
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
importall Lint
"""
msgs = lintstr(s)
@test isempty(msgs)

# Avoid warning users about dynamic includes.
s = """
script = \"test.jl\"; include(script)
"""
msgs = lintstr(s)
@test msgs[1].code == :I372
@test isempty(filter(x -> !isinfo(x), msgs))
