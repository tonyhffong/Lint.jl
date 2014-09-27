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

s = """
function f()
    @gensym x y z
    println( x )
    println( y )
    println( z )
end
"""
msgs = lintstr( s )
@assert( isempty( msgs ) )
