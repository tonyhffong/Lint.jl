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
@test isempty(msgs)
