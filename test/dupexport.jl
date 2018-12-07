s = """
module Test
export f

function f(x)
    x+1
end

export f #AGAIN!!
end
"""

msgs = lintstr(s)
@test msgs[1].code == :E333
@test occursin("duplicate exports of symbol", msgs[1].message)
