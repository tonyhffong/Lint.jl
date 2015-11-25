p = "non_existing_1234_4321"
@test !ispath( p )
@test_throws( AbstractString, lintfile( p ) )
@test_throws( AbstractString, lintpkg( p ) )
