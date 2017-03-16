using Lint
using Compat
using Base.Test

messageset(msgs) = Set(x.code for x in msgs)

include("statictype.jl")

@testset "Lint File" begin
    path = joinpath(@__DIR__, "DEMOFILE.jl")
    @test !isempty(lintfile(path))
end

@testset "AST Linting" begin
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
    include("stagedfuncs.jl")
    include("incomplete.jl")
    include("misuse.jl")
end

include("bugs.jl")
include("lintself.jl")

@testset "Server" begin
    include("server.jl")
end
