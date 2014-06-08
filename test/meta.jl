s = """
function f()
    local internalsym = :sym
    ret = quote
        immutable \$internalsym end
    end
    ret
end
"""
msgs = lintstr(s)

@assert( isempty(msgs) )
