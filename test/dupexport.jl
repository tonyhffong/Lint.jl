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
@test msgs[1].code == 333
@test contains(msgs[1].message, "duplicate exports")
