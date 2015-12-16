# we must run these scripts explicitly since they are not real packages in standard directories
include("DEMOMODULE.jl") # this provide the macro that generates functions
include("DEMOMODULE2.jl") # this uses the first module's macro. It would export the generated functions

msgs = lintfile("DEMOMODULE2.jl"; returnMsgs = true)
@test isempty(msgs)

msgs = lintfile("DEMOMODULE3.jl"; returnMsgs = true)
@test msgs[1].code == :E311
@test contains(msgs[1].message, "cannot find include file:")
