"""
    Lint.SemanticASTs

This module provides types for an annotated abstract syntax tree with nodes
based off semantic information.
"""
module SemanticASTs

using ..RequiredKeywordArguments

using Base.Meta
using Compat
import Base.show

# for code readability purposes
const AST = Any

export SemanticAST, FunctionName, InstanceFunctionName, TypeFunctionName,
       Signature, Quantification, Lambda, MethodDefinition, Unannotated,
       annotateⁿ, rawastⁿ

"""
    SemanticAST

An annotated expression. An expression is something which can be meaningfully
evaluated into a value in a particular context. For example, `:(1 + 1)` and
`:foo` are expressions. In Julia, even `type Foo end` is an expression, because
it evaluates to `nothing` in the global context.
"""
@compat abstract type SemanticAST end

rawastⁿ(ast::SemanticAST) = Nullable(rawast(ast))
nameⁿ(ast::SemanticAST) = Nullable(name(ast))

include("functionname.jl")
include("functiondef.jl")

immutable Unannotated <: SemanticAST
    _ast       :: AST
end
rawast(ast::Unannotated) = ast._ast

function show(io::IO, ast::Unannotated)
    print(io, "Unannotated(")
    show(io, get(rawastⁿ(ast)))
    print(io, ")")
end

"""
    SemanticAST(x::Expr)

```jldoctest
julia> SemanticAST(:(f(x) = x))
MethodDefinition(
    to=InstanceFunctionName(func=Unannotated(:f)),
    method=Lambda(signature=Signature(:((x,))))
)

julia> functionname(:(function (::Type{Foo})(); Foo(1); end))
:Foo

julia> functionname(:(function (p::Polynomial)(); p(0); end))
:(::Polynomial)

julia> functionname(:(macro foo(); end))
Symbol("@foo")
```
"""
function SemanticAST(ex::Expr)
    if isexpr(ex, :function)
        # parse as function
    elseif isexpr(ex, :macro)
    else
        Unannotated(ex)
    end
end

SemanticAST(ex) = Unannotated(ex)

end
