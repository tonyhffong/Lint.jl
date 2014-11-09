s = """
stagedfunction f(a,b)
    if a==1
        :(b)
    elseif b == Int
        :(a)
    else
        :(0)
    end
end
"""

msgs = lintstr( s )
@test contains( msgs[1].message, "incompatible types (#1)" )
