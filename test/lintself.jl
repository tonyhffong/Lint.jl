println("Linting Lint itself")
msgs = lintpkg("Lint")
if !isempty(msgs)
    display(msgs)
end
@test isempty(msgs)
@test length(msgs) === 0
@test size(msgs) === (0,)
@test_throws BoundsError msgs[1]
