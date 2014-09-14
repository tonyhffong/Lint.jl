include( "DEMOMODULE.jl") # this provide the macro that generates functions
include( "DEMOMODULE2.jl") # this uses the first module's macro. It would export the generated functions

msgs = lintfile( "DEMOMODULE2.jl"; returnMsgs = true )
@assert( isempty( msgs ) )
