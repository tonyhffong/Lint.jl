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

s = """
import Compat
f = Compat.rewrite_dict(:(a=b))
"""
msgs = lintstr(s)
@test isempty(msgs)
