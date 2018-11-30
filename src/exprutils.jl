module ExpressionUtils

using Base.Meta
# using ..LintCompat

export split_comparison, simplify_literal, ispairexpr, isliteral,
       lexicaltypeof, lexicalfirst, lexicallast, lexicalvalue,
       withincurly, expand_trivial_calls, expand_assignment, COMPARISON_OPS,
       understand_import, dots, kind, path

"""
    withincurly(ex)

Get just the function part of a function declaration, or just the type head of
a parameterized type name.

```jldoctest
julia> using Lint.ExpressionUtils

julia> withincurly(:(Vector{T}))
:Vector

julia> withincurly(:((::Type{T}){T}))
:(::Type{T})
```
"""
withincurly(ex) = isexpr(ex, :curly) ? ex.args[1] : ex

"""
    split_comparison(::Expr)

Split a :comparison expression into an equivalent :&& expression, given that
each component of the comparison is pure.
"""
function split_comparison(ex)
    if !isexpr(ex, :comparison)
        throw(ArgumentError("expected a comparison expression, got a $(ex.head)"))
    end
    left = ex.args[1]
    op = ex.args[2]
    right = ex.args[3]
    remainder = ex.args[3:end]
    if length(remainder) == 1
        :($op($left, $right))
    else
        :($op($left, $right) &&
          $(split_comparison(Expr(:comparison, remainder...))))
    end
end

"""
    simplify_literal(::Expr)

Simplify certain macros into the literals they produce.

Simplifications performed include:

 - v"x.y.z" literals are simplified into `VersionNumber` objects.
"""
function simplify_literal(ex)
    if isexpr(ex, :macrocall) && ex.args[1] == Symbol("@v_str") &&
       isa(ex.args[2], AbstractString)
        VersionNumber(ex.args[2])
    else
        ex
    end
end

"""
Return `true` if `x` is an expression of the form `:(k => v)`.  Note that on
v0.5, this is `Expr(:(=>), ...)`, whereas on v0.6 it is `Expr(:call, :(=>),
...)`.
"""
ispairexpr(x) = isexpr(x, :(=>)) || isexpr(x, :call) && x.args[1] == :(=>)

"""
Return the first entry of the given pair expression, determined lexically.
Note that on v0.5, this is the first argument of the expression, whereas on
v0.6, this is the second argument of the expression.
"""
lexicalfirst(x) = VERSION < v"0.6.0-dev.2613" ? x.args[1] : x.args[2] # changed by julia PR #20327

"""
Return the last entry of the given pair expression, determined lexically.  Note
that on v0.5, this is the second argument of the expression, whereas on v0.6,
this is the third argument of the expression.
"""
lexicallast(x) = VERSION < v"0.6.0-dev.2613" ? x.args[2] : x.args[3] # changed by julia PR #20327

"""
Return `true` if the value represented by expression `x` is exactly `x` itself;
that is, `x` is not `Expr`, `LineNumberNode`, `QuoteNode`, or `Symbol`.
"""
isliteral(x) = !any(t->isa(x, t), [Expr LineNumberNode QuoteNode Symbol])

"""
    lexicalvalue(x) :: Union{Any, Nothing}

If `x` is a literal, or a quoted literal, return that literal.
Otherwise, return `nothing`.
"""
function lexicalvalue(x)
    if isliteral(x)
        x
    elseif isexpr(x, :quote)
        if isexpr(x.args[1], :($))
            lexicalvalue(x.args[1].args[1])
        else
            x.args[1]
        end
    elseif isa(x, QuoteNode)
        x.value
    else
        nothing
    end
end

"""
Return the most specific known lexical type of the given expression. Lexical
type is defined as

- If the expression is a literal, the type of that literal;
- If the expression is a `QuoteNode`, or an `Expr(:quote, ...)`, the type of
  whatever is quoted;
- Otherwise, `Any`.

That is, the maximal amount of information detectable from the lexical context
alone.
"""
function lexicaltypeof(x)
    lex_value = lexicalvalue(x)
    if lex_value == nothing
        return Nothing
    end
    broadcast(typeof, lex_value)
end

"""
    expand_trivial_calls(x)

Expand the outer layer of trivial calls. Trivial calls are defined as
expression nodes that almost always lower to calls but are not represented as
such. The special case lowering of `A*B'` is neglected.
"""
function expand_trivial_calls(ex)
    if isexpr(ex, Symbol("'"))
        Expr(:call, :ctranspose, ex.args...)
    elseif isexpr(ex, :(=>))
        Expr(:call, :(=>), ex.args...)
    elseif isexpr(ex, :vect)
        Expr(:call, :(Base.vect), ex.args...)
    else
        ex
    end
end

# TODO: deal with dot-calls
"""
    expand_assignment(x)

Return a tuple `(LHS, RHS)` by expanding the expression as if it represents a
single assignment. For example, `x += y` is expanded to `x = x + y`, which is
returned as `(x, x + y)`. Return `nothing` if the argument could not be
interpreted as an assignment.
"""
function expand_assignment(expr::Expr)::Union{Any, Nothing}
    op = expr.head
    if op in COMPARISON_OPS
        nothing
    elseif op == :(=)
        @assert length(expr.args) == 2
        (expr.args[1], expr.args[2])
    else
        str = string(op)
        if str[end] == '='
            fop = Symbol(str[1:end-1])
            @assert length(expr.args) == 2
            (expr.args[1], Expr(:call, fop, expr.args[1], expr.args[2]))
        else
            nothing
        end
    end
end
expand_assignment(_) = nothing

const COMPARISON_OPS = [:(==), :(<), :(>), :(<=), :(>=), :(!=)]

struct Import
    """
    The number of dots preceding the import. If `dots` is `0`, then this is a
    toplevel import (i.e., from Main, but additionally requiring the module if
    it is not already loaded). A value of `1` indicates importing something
    from this module (typically only useful for `using`). From there, any
    increase of `1` to `dots` will move up one level to the parent module,
    until it is `Main`, after which adding more dots does not change the
    result.
    """
    dots :: Int

    """
    After any dots, the series of modules that must be loaded to obtain the
    object to be imported. All but the last of these should represent a module.
    """
    path :: Vector{Symbol}

    """
    If this is `:import`, then the given symbol is simply imported into the
    current namespace. If it is `:importall`, then that is done, and if the
    loaded object is a module, all its exports are also imported. If it is
    `:using`, then the effect is like `:importall`, except the imported symbols
    are not available for method extension.
    """
    kind :: Symbol
end
dots(imp::Import) = imp.dots
path(imp::Import) = imp.path
kind(imp::Import) = imp.kind

"""
    understand_import(ex)::Union{Import, Nothing}

Return an `Import` from extracting the important semantics from the given
expression `ex`, or `nothing` otherwise.
"""
function understand_import(ex)::Union{Import, Nothing}
    if !isexpr(ex, [:using, :import, :importall])
        return nothing
    end

    kind = ex.head
    dots = 0
    for x in ex.args
        if x === :.
            dots += 1
        else
            break
        end
    end
    path = ex.args[dots+1:end]

    Import(dots, path, kind)
end

end
