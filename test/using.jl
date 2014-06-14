s = """
module Test
using TestBase
end
"""
msgs = lintstr(s)

@assert( contains( msgs[1].message, "doesn't eval into a Module" ) )

module TestBase
export foobar
foobar(x) = x
end


s = """
module Test
using TestBase
g(x) = foobar(x)
end
"""
msgs = lintstr(s)
@assert( isempty(msgs))
