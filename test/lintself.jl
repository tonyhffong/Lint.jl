if basename( pwd() ) == "Lint"
    path =  "src/Lint.jl"
elseif basename( pwd() ) == "src"
    path = "Lint.jl"
elseif basename( pwd() ) == "test"
    path = "../src/Lint.jl"
else
    throw( "doesn't know where I am." )
end

msgs = lintfile( path; returnMsgs = true )

@assert( isempty( msgs ) )
