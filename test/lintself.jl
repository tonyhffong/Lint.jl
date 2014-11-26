println( "Linting Lint itself")
msgs = lintpkg( "Lint"; returnMsgs = true )
#println( msgs )
sumseverity = 0
if !isempty( msgs )
    sumseverity = sum( x->x.level, msgs )
end
@test sumseverity == 0
