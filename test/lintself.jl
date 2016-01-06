println("Linting Lint itself")
msgs = lintpkg("Lint"; returnMsgs = true)
# println(msgs)
@test isempty(msgs)
