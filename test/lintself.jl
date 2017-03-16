@testset "Lint Self" begin
    msgs = lintpkg("Lint")
    if !isempty(msgs)
        display(msgs)
    end
    # TODO: reenable when #200 fixed
    # @test isempty(msgs)
    # @test length(msgs) === 0
    # @test size(msgs) === (0,)
    # @test_throws BoundsError msgs[1]
end
