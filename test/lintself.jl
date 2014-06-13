msgs = lintfile( "../src/Lint.jl" )

@assert( isempty( msgs ) )
