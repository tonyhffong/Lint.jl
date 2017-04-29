"""
    Signature

The signature of a function.
"""
immutable Signature <: SemanticAST
    _ast       :: AST
end
rawast(ast::Signature) = ast._ast

function show(io::IO, ast::Signature)
    print(io, "Signature(")
    show(io, rawast(ast))
    print(io, ")")
end

"""
    Quantification

A parameter introduced by `where` in a method definition, including any bounds;
for example, the `T <: Number` in `f(x::T, y::T) where T <: Number`.
"""
immutable Quantification <: SemanticAST
    _ast       :: Nullable{AST}
    name       :: Symbol
    lowerbound :: Nullable{SemanticAST}
    upperbound :: Nullable{SemanticAST}
end
name(ast::Quantification) = ast.name
lowerboundⁿ(ast::Quantification) = ast.lowerbound
upperboundⁿ(ast::Quantification) = ast.upperbound

Quantification(ast=Nullable();
    @required(name::Symbol),
    lowerbound=Nullable(),
    upperbound=Nullable()
) = Quantification(ast, name, lowerbound, upperbound)

function show(io::IO, ast::Quantification)
    print(io, "Quantification(name=")
    show(io, name(ast))
    if !isnull(lowerboundⁿ(ast))
        print(io, ", lowerbound=", lowerboundⁿ(ast))
    end
    if !isnull(upperboundⁿ(ast))
        print(io, ", upperbound=", upperboundⁿ(ast))
    end
    print(io, ")")
end

function annotateⁿ(::Type{Quantification}, ast::AST)::Nullable
    name = if isa(ast, Symbol)
        Quantification(name=ast)
    elseif isexpr(ast, :comparison) && length(ast.args) == 5 &&
           ast.args[2] == ast.args[4] == :(<:) && isa(ast.args[3], Symbol)
        Quantification(name=ast.args[3],
                        lowerbound=SemanticAST(ast.args[1]),
                        upperbound=SemanticAST(ast.args[5]))
    elseif isexpr(ast, :(<:)) && isa(ast.args[1], Symbol)
        Quantification(name=ast.args[1], upperbound=SemanticAST(ast.args[2]))
    elseif isexpr(ast, :(>:)) && isa(ast.args[1], Symbol)
        Quantification(name=ast.args[1], lowerbound=SemanticAST(ast.args[2]))
    else
        Nullable()
    end
end

"""
    FunctionDefinition

A definition of a named or anonymous function.
"""
@compat abstract type FunctionDefinition <: SemanticAST end

"""
    Lambda

An anonymous function, including the signature, body, any static parameters,
and return type declaration if applicable.
"""
immutable Lambda <: FunctionDefinition
    _ast       :: Nullable{AST}
    sparams    :: Vector{Quantification}
    signature  :: Signature
    returntype :: Nullable{SemanticAST}
    code       :: SemanticAST
end
rawastⁿ(ast::Lambda) = ast._ast
sparams(ast::Lambda) = ast.sparams
signature(ast::Lambda) = ast.signature
returntypeⁿ(ast::Lambda) = ast.returntype
code(ast::Lambda) = ast.code

Lambda(ast=Nullable();
    sparams=Quantification[],
    @required(signature::Signature),
    returntype=Nullable(),
    @required(code::SemanticAST)
) = Lambda(ast, sparams, signature, returntype, code)

function show(io::IO, ast::Lambda)
    print(io, "Lambda(")
    if !isempty(sparams(ast))
        print("sparams=", sparams(ast), ", ")
    end
    print("signature=", signature(ast), ", ")
    if !isnull(returntypeⁿ(ast))
        print("returntype=", get(returntype(ast)), ", ")
    end
    print("code=", code(ast), ")")
end

"""
    MethodDefinition

A definition of a method, including the function name, signature, body, any
static parameters, and return type declaration if applicable.
"""
immutable MethodDefinition <: FunctionDefinition
    _ast       :: Nullable{AST}
    sparams    :: Vector{Quantification}
    func       :: FunctionName
    signature  :: Signature
    returntype :: Nullable{SemanticAST}
    code       :: SemanticAST
end
rawastⁿ(ast::MethodDefinition) = ast._ast
sparams(ast::MethodDefinition) = ast.sparams
func(ast::MethodDefinition) = ast.func
signature(ast::MethodDefinition) = ast.signature
returntypeⁿ(ast::MethodDefinition) = ast.returntype
code(ast::MethodDefinition) = ast.code

MethodDefinition(ast=Nullable();
    sparams=Quantification[],
    @required(func::FunctionName),
    @required(signature::Signature),
    returntype=Nullable(),
    @required(code::SemanticAST)
) = MethodDefinition(ast, sparams, func, signature, returntype, code)

function show(io::IO, ast::MethodDefinition)
    print(io, "MethodDefinition(")
    if !isempty(sparams(ast))
        print("sparams=", sparams(ast), ", ")
    end
    print("func=", func(ast), ", ")
    print("signature=", signature(ast), ", ")
    if !isnull(returntypeⁿ(ast))
        print("returntype=", get(returntype(ast)), ", ")
    end
    print("code=", code(ast), ")")
end
