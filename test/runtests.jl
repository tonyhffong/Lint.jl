using Lint
using Base.Test

println( "test basic printing and sorting of lint messages")

if basename( pwd() ) == "Lint"
    path =  "test/DEMOFILE.jl"
elseif basename( pwd() ) == "src"
    path = "../test/DEMOFILE.jl"
elseif basename( pwd() ) == "test"
    path = "DEMOFILE.jl"
else
    throw( "doesn't know where I am." )
end

lintfile( path )

println( "test core lint functionalities" )
include( "array.jl")
include( "bitopbool.jl" )
include( "comprehensions.jl")
include( "deadcode.jl" )
include( "deprecate.jl" )
include( "dictkey.jl" )
include( "dupexport.jl" )
include( "forloop.jl")
include( "funcall.jl")
include( "globals.jl")
include( "ifstmt.jl")
include( "import.jl")
include( "lambda.jl")
include( "macro.jl" )
include( "mathconst.jl")
include( "module.jl" )
include( "meta.jl" )
include( "pragma.jl" )
include( "range.jl")
include( "similarity.jl" )
include( "strings.jl")
include( "symbol.jl")
include( "type.jl")
include( "undeclare.jl" )
include( "unusedvar.jl")
include( "using.jl")

include( "lintself.jl")
