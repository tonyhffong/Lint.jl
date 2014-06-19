s = """
function f(x)
    for i in [:a=>1, :b=>2 ]
    end
    return x
end
"""
msgs = lintstr(s)
@test( contains( msgs[1].message, "iteration over dictionary uses a (k,v) tuple" ))
