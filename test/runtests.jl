using Lint
using Base.Test

messageset(msgs) = Set(x.code for x in msgs)

println("Test basic printing and sorting of lint messages")

if basename(pwd()) == "Lint"
    path =  "test/DEMOFILE.jl"
elseif basename(pwd()) == "src"
    path = "../test/DEMOFILE.jl"
elseif basename(pwd()) == "test"
    path = "DEMOFILE.jl"
else
    throw("doesn't know where I am")
end

lintfile(path)

println("...OK\n\nTest core lint functionalities...")
include("messages.jl")
include("basics.jl")
include("array.jl")
include("badvars.jl")
include("bitopbool.jl")
include("comprehensions.jl")
include("curly.jl")
include("deadcode.jl")
include("deprecate.jl")
include("dictkey.jl")
include("doc.jl")
include("dupexport.jl")
include("forloop.jl")
include("funcall.jl")
include("globals.jl")
include("ifstmt.jl")
include("import.jl")
include("lambda.jl")
include("linthelper.jl")
include("macro.jl")
include("mathconst.jl")
include("module.jl")
include("meta.jl")
include("pragma.jl")
include("range.jl")
include("ref.jl")
include("similarity.jl")
include("strings.jl")
include("style.jl")
include("symbol.jl")
include("throw.jl")
include("tuple.jl")
include("type.jl")
include("typecheck.jl")
include("undeclare.jl")
include("unusedvar.jl")
include("using.jl")
include("versions.jl")
include("server.jl")
include("stagedfuncs.jl")
include("incomplete.jl")
include("misuse.jl")
include("bugs.jl")

println("...OK\n")
include("lintself.jl")
println("...OK")
