p = "non_existing_1234_4321"
@test !ispath( p )
@test_throws( String, lintfile( p ) )
@test_throws( String, lintpkg( p ) )
