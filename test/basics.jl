@test_throws( ErrorException, lintfile( "non_existing_file" ) )
@test_throws( ErrorException, lintpkg( "non_existing_pkg" ) )
