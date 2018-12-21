s = """
module test; if true; end
"""
msgs = lintstr(s)
@test msgs[1].code == :E112
@test occursin("incomplete:", msgs[1].message)

s = """
2 +
"""
msgs = lintstr(s)
@test msgs[1].code == :E112
@test occursin("incomplete:", msgs[1].message)
