# give the macro linter a workout

s = """
macro r_str(pattern, flags...) Regex(pattern, flags...) end
"""
msgs = lintstr( s )

@assert( isempty( msgs ) )

s = """
macro schedule(expr)
    expr = localize_vars(:(()->(\$expr)), false)
    :(enq_work(Task(\$(esc(expr)))))
end
"""
msgs = lintstr( s )

@assert( isempty( msgs ) )

s = """
i = 1
@label testlabel
i = i +1
if i < 10
    @goto testlabel
end
"""
msgs = lintstr( s )
@assert( length( msgs ) == 2 )
@assert( contains( msgs[1].message, "experimental feature" ) )
@assert( contains( msgs[2].message, "experimental feature" ) )
s = """
@windows ? 1 : 2
"""
msgs = lintstr( s )
@assert( isempty( msgs ) )

s = """
@deprecate put put!
@deprecate readsfrom(cmd, args...)      open(cmd, "r", args...)
"""
msgs = lintstr( s )
@assert( isempty( msgs ) )
