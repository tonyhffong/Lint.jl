p = "non_existing_1234_4321"
@test !ispath(p)

@test_throws(AbstractString, lintfile(p))
@test_throws(AbstractString, lintpkg(p))

# Lint package with full path
msgs = lintpkg(joinpath(Base.Filesystem.dirname(Base.find_package("Lint")), "test", "FakePackage"))
@test isempty(msgs)
