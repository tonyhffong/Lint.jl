println("Linting Lint itself")
msgs = lintpkg("Lint")
# println(msgs)
@test isempty(msgs)
@test length(msgs) === 0
@test size(msgs) === (0,)
@test_throws BoundsError msgs[1]
