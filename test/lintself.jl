println( "Linting Lint itself")
msgs = lintpkg( "Lint"; returnMsgs = true )
println( msgs )
@assert( isempty( msgs ) )
