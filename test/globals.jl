s = """
y=1
function f(x)
    x + y
end
"""
msgs = lintstr( s )
@test( length(msgs) == 0)

s = """
y = 1
function f(x)
    global y = 2
    x + y
end
"""
msgs = lintstr(s)
@test( length(msgs) == 0 )

s = """
yyyyyy = 1
function f(x)
    yyyyyy = 2
    x + yyyyyy
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "also a global"))

s = """
y= 1
function f(x)
    y= 2
    x + y
end
"""
msgs = lintstr(s)
@test( length(msgs)==0 ) # short names are grandfathered to be ok
s = """
const y= 1
function f(x)
    y= 2
    x + y
end
"""
msgs = lintstr(s)
@test( length(msgs)==0 ) # short names are grandfathered to be ok
s = """
const y
function f(x)
    y= 2
    x + y
end
"""
msgs = lintstr(s)
@test( contains(msgs[1].message, "expected assignment after \\\"const\\\"") )
