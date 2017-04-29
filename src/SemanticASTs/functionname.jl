"""
    FunctionName

A function name is something that methods can validly be added to.
"""
@compat abstract type FunctionName <: SemanticAST end

"""
    InstanceFunctionName

A function name for a particular instance, as in `f(x)` or `Base.show(x, y)`.
The instance here should represent a singleton, or a simple name in the case of
a closure.
"""
immutable InstanceFunctionName <: FunctionName
    _ast       :: Nullable{AST}
    instance   :: SemanticAST
end
rawastⁿ(ast::InstanceFunctionName) = ast._ast
instance(ast::InstanceFunctionName) = ast.instance

InstanceFunctionName(ast=Nullable();
    @required(instance::SemanticAST)
) = InstanceFunctionName(ast, instance)

function show(io::IO, ast::InstanceFunctionName)
    print(io, "InstanceFunctionName(instance=", instance(ast), ")")
end

"""
    TypeFunctionName

A function name for a particular type, as in `(::Polynomial)(x)`.  Optionally,
the function name is given a name, like in `(p::Polynomial)(x)`.
"""
immutable TypeFunctionName <: FunctionName
    _ast       :: Nullable{AST}
    name       :: Nullable{Symbol}
    paramtype  :: SemanticAST
end
rawastⁿ(ast::TypeFunctionName) = ast._ast
nameⁿ(ast::TypeFunctionName) = ast.name
paramtype(ast::TypeFunctionName) = ast.paramtype

TypeFunctionName(ast=Nullable();
    name=Nullable(),
    @required(paramtype::SemanticAST)
) = TypeFunctionName(ast, name, paramtype)

function show(io::IO, ast::TypeFunctionName)
    print(io, "TypeFunctionName(")
    if !isnull(nameⁿ(ast))
        print(io, "name=")
        show(io, get(nameⁿ(ast)))
        print(io, ", ")
    end
    print(io, "paramtype=", paramtype(ast), ")")
end

"""
    annotateⁿ(FunctionName, ast)

Return, wrapped in a `Nullable`, the given `ast` with extra semantic
information computed given that `ast` represents the function name part of a
method definition. If it cannot be understood that way, return `Nullable()`.
"""
function annotateⁿ(::Type{FunctionName}, ast::AST)::Nullable
    if isexpr(ast, :(::))
        if length(ast.args) == 1
            return TypeFunctionName(ast; paramtype=Unannotated(ast.args[1]))
        elseif length(ast.args) == 2 && isa(ast.args[1], Symbol)
            return TypeFunctionName(ast; name=ast.args[1], paramtype=Unannotated(ast.args[2]))
        end
    elseif isa(ast, Symbol) || isexpr(ast, :(.)) || isexpr(ast, :curly)
        return InstanceFunctionName(ast; instance=Unannotated(ast))
    end
    Nullable()
end
