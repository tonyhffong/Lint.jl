println( "Linting Lint itself")
msgs = lintpkg( "Lint"; returnMsgs = true )
@assert( isempty( msgs ) )
