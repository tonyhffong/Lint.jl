p = "non_existing_1234_4321"
@test !ispath( p )
@test_throws( ErrorException, lintfile( p ) )
@test_throws( ErrorException, lintpkg( p ) )
