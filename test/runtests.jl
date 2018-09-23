using Lint
using Compat
using Test

messageset(msgs) = Set(x.code for x in msgs)

include("exprutils.jl")
include("statictype.jl")

@testset "Lint Messages" begin
    include("messages.jl")
end

try
    @testset "AST Linting" begin
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
        include("macro.jl")
        include("meta.jl")
        include("pragma.jl")
        include("range.jl")
        include("ref.jl")
        include("similarity.jl")
        include("strings.jl")
        include("style.jl")
        include("I340.jl")
        include("I341.jl")
        include("I343.jl")
        include("I481.jl")
        include("W361.jl")
        include("E100.jl")
        include("throw.jl")
        include("tuple.jl")
        include("type.jl")
        include("typecheck.jl")
        include("undeclare.jl")
        include("using.jl")
        include("versions.jl")
        include("stagedfuncs.jl")
        include("incomplete.jl")
        include("misuse.jl")
    end
end

@testset "Lint File" begin
    path = joinpath(@__DIR__, "DEMOFILE.jl")
    @test !isempty(lintfile(path))
end

try include("linthelper.jl") end
include("bugs.jl")
include("lintself.jl")

try
@testset "Server" begin
    include("server.jl")
end
end
