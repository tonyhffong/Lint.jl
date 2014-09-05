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
