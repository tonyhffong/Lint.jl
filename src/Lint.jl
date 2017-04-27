__precompile__(true)

module Lint

using Base.Meta
using Compat
using Compat: TypeUtils, readline
using JSON
using AutoHashEquals

if isdefined(Base, :unwrap_unionall)
    using Base: unwrap_unionall
else
    unwrap_unionall(x) = x
end

export LintMessage, LintContext
export lintfile, lintstr, lintpkg, lintserver, @lintpragma
export iserror, iswarning, isinfo
export test_similarity_string

const SIMILARITY_THRESHOLD = 10.0

# no-op. We have to use macro inside type declaration as it disallows actual function calls
macro lintpragma(s)
end

# needed for BROADCAST
include("compat.jl")
using .LintCompat
include("exprutils.jl")
using .ExpressionUtils

include("statictype.jl")

include("linttypes.jl")
include("guesstype.jl")
include("result.jl")

# AST Linting
include("abstracteval.jl")
include("ast.jl")
include("blocks.jl")
include("controls.jl")
include("curly.jl")
include("dict.jl")
include("dynamic.jl")
include("functions.jl")
include("generator.jl")
include("include.jl")
include("knowndeprec.jl")
include("macros.jl")
include("misc.jl")
include("modules.jl")
include("pragma.jl")
include("ref.jl")
include("types.jl")
include("variables.jl")

# Command-Line Interface
include("cli.jl")

# Server
include("server.jl")

# precompile hints
include("init.jl")
include("precompile.jl")

end
