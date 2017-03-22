try
@testset "Lint Self" begin
    msgs = lintpkg("Lint")
    if !isempty(msgs)
        display(msgs)
    end
    # TODO: reenable when #200 fixed
    @test_broken isempty(msgs)
    @test_broken length(msgs) === 0
    @test_broken size(msgs) === (0,)
    # @test_throws BoundsError msgs[1]
end
end
