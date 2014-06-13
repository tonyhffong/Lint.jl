msgs = lintfile( "../src/Lint.jl"; returnMsgs = true )

@assert( isempty( msgs ) )
