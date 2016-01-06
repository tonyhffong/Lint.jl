s = """
module Test
export foobar
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E322
@test contains(msgs[1].message, "exporting undefined symbol")
