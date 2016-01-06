s = """
ex = :(1+x)
f = eval(:(x->(\$ex)))
"""
msgs = lintstr(s)
@test isempty(msgs)

