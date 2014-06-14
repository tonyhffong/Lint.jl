s = """
module Test
using TmpTestBase
end
"""
msgs = lintstr(s)

@assert( contains( msgs[1].message, "doesn't eval into a Module" ) )

module TmpTestBase
export foobar
foobar(x) = x
end


s = """
module Test
using TmpTestBase
g(x) = foobar(x)
end
"""
msgs = lintstr(s)
@assert( isempty(msgs))
