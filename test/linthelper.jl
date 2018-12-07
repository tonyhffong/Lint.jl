try
@testset "Lint Helper" begin
    # we must run these scripts explicitly since they are not real packages in standard directories
    include("DEMOMODULE.jl") # this provide the macro that generates functions
    include("DEMOMODULE2.jl") # this uses the first module's macro. It would export the generated functions

    msgs = lintfile("DEMOMODULE2.jl")
    @test_broken isempty(msgs)

    msgs = lintfile("DEMOMODULE3.jl")
    @test_broken msgs[1].code == :E311
    @test_broken occursin("cannot find include file", msgs[1].message)
end
end
