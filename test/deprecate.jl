@testset "Deprecation" begin
Lint.addDummyDeprecates()

s = """
function testDep1(x)
    x
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E211
@test occursin("generic deprecate message", msgs[1].message)

# THIS DOESN'T TRIGGER LINT WARNING SINCE THE SIGNATURE DOESN'T MATCH
s = """
function testDep2(x::Int, y)
    x + y
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
function testDep2(x::Complex{Int})
    x
end
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
function testDep2(x::Int...)
    x
end
"""
msgs = lintstr(s)
@test isempty(msgs)
# END OF NON-MATCHING SIGNATURES

s = """
function testDep2(x::Int)
    x
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E211
@test occursin("generic deprecate message", msgs[1].message)

s = """
function testDep3{T <: Real}(x::Array{T,1})
    x
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E211
@test occursin("generic deprecate message", msgs[1].message)

s = """
function testDep4(x::Int, y::Int...)
    x + length(y)
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E211
@test occursin("generic deprecate message", msgs[1].message)

s = """
function testDep4(x::Int, y::Int)
    x + length(y)
end
"""
msgs = lintstr(s)
@test msgs[1].code == :E211
@test occursin("generic deprecate message", msgs[1].message)

s = """
function testDep5{T <: AbstractString}(x::Array{T,1})
    x
end
"""
msgs = lintstr(s)
@test isempty(msgs)
end
