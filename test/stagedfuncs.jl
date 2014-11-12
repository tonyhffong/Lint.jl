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

# if it is not a staged function, it would have no lint message
s = """
stagedfunction f(x)
    :(x+y)
end
"""
msgs = lintstr( s )
@test contains( msgs[1].message, "Use of undeclared symbol" )

s = """
stagedfunction f( args::Int... )
    @lintpragma( "Info type args")
    x = args[1]
    @lintpragma( "Info type x")
    :( show( x,args... ) )
end
"""
msgs = lintstr(s)
@test contains( msgs[1].message, "typeof( args ) == (DataType...,)")
@test contains( msgs[2].message, "typeof( x ) == DataType" )
