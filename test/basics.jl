p = "non_existing_1234_4321"
@test !ispath(p)
@test_throws(AbstractString, lintfile(p))
@test_throws(AbstractString, lintpkg(p))

# Lint package with full path
msgs = lintpkg(joinpath(Pkg.dir("Lint"), "test", "FakePackage"); returnMsgs = true)
Lint.display_messages(msgs)
@test isempty(msgs)
