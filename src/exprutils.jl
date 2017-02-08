module ExpressionUtils

using Base.Meta

export split_comparison, simplify_literal

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

end
