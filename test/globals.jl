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
s = """
global 5
"""
msgs = lintstr(s)
@test( contains(msgs[1].message, "unknown global pattern") )

s = """
f() = x
x = 5
"""
msgs = lintstr(s)
@test( length(msgs)==0 )

s = """
x
x = 5
"""
msgs = lintstr(s)
@test( contains(msgs[1].message, "Use of undeclared symbol") )

# Test gloabls defined in other files
# File in package src
msgs = lintfile( "FakePackage/src/subfolder2/file2.jl"; returnMsgs = true )
@test( length(msgs)==0 )
# File in package test
msgs = lintfile( "FakePackage/test/file2.jl"; returnMsgs = true )
@test( length(msgs)==0 )
# File in base julia
msgs = lintfile( "FakeJulia/base/file2.jl"; returnMsgs = true )
@test( length(msgs)==0 )
