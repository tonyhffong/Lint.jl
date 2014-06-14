s = """
module Test
export foobar
end
"""
msgs = lintstr(s)

@assert( contains( msgs[1].message, "undefined symbol" ))
