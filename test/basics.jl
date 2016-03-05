p = "non_existing_1234_4321"
@test !ispath(p)

if VERSION < v"0.5-"
@test_throws(AbstractString, lintfile(p))
@test_throws(AbstractString, lintpkg(p))
else
@test_throws(ASCIIString, lintfile(p))
@test_throws(UTF8String, lintpkg(p))
end

# Lint package with full path
msgs = lintpkg(joinpath(Pkg.dir("Lint"), "test", "FakePackage"); returnMsgs = true)
Lint.display_messages(msgs)
@test isempty(msgs)
