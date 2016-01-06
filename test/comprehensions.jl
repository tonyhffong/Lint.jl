s = """[i for i in 1:2]
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
[j => j*j for j in 1:2]
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
(Int=>Int)[y2 => y2*y2 for y2 in 1:2]
"""
msgs = lintstr(s)
@test isempty(msgs)
