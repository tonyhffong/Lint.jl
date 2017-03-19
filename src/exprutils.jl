module ExpressionUtils

using Base.Meta

export split_comparison, simplify_literal, ispairexpr, isliteral,
       lexicaltypeof, lexicalfirst, lexicallast, lexicalvalue,
       withincurly, expand_trivial_calls

# TODO: remove when 0.5 support dropped
function BROADCAST(f, x::Nullable)
    if isnull(x)
        Nullable()
    else
        Nullable(f(get(x)))
    end
end

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
that is, `x` is not `Expr`, `QuoteNode`, or `Symbol`.
"""
isliteral(x) = !isa(x, Expr) && !isa(x, QuoteNode) && !isa(x, Symbol)

"""
    lexicalvalue(x) :: Nullable{Any}

If `x` is a literal, or a quoted literal, return that literal wrapped in a
`Nullable`. Otherwise, return `Nullable{Any}()`.
"""
function lexicalvalue(x)
    if isliteral(x)
        Nullable{Any}(x)
    elseif isexpr(x, :quote)
        if isexpr(x.args[1], :($))
            lexicalvalue(x.args[1].args[1])
        else
            Nullable{Any}(x.args[1])
        end
    elseif isa(x, QuoteNode)
        Nullable{Any}(x.value)
    else
        Nullable{Any}()
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
lexicaltypeof(x) = get(BROADCAST(typeof, lexicalvalue(x)), Any)

"""
    expand_trivial_calls(x)

Expand the outer layer of trivial calls. Trivial calls are defined as
expression nodes that almost always lower to calls but are not represented as
such. The special case lowering of `A*B'` is neglected.
"""
function expand_trivial_calls(ex)
    if isexpr(ex, :(:))
        Expr(:call, :colon, ex.args...)
    elseif isexpr(ex, Symbol("'"))
        Expr(:call, :ctranspose, ex.args...)
    elseif isexpr(ex, Symbol(".'"))
        Expr(:call, :transpose, ex.args...)
    elseif isexpr(ex, :(=>))
        Expr(:call, :(=>), ex.args...)
    else
        ex
    end
end

end
