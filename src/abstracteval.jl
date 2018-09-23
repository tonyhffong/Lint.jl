"""
    abstract_eval(ctx::LintContext, ex) :: Union{Any, Nothing}

Like `eval`, but does it in the current context and without any dynamism.
Returns `nothing` if the result can't be evaluated.
"""
abstract_eval(ctx::LintContext, ex::Symbol) =
    flatten(BROADCAST(extractobject, lookup(ctx, ex)))

"""
    abstract_eval(ctx::LintContext, ex::Expr) :: Union{Any, Nothing}

If the given expression is curly, and each component of the curly is a constant
object in the given `ctx`, construct the object `x` as would have been done in
the program itself, and return `x`.

Otherwise, if the given expression is `foo.bar`, and `foo` is a standard
library object with attribute `bar`, then construct `foo.bar` as would be done
in the program itself and return it.

Otherwise, return `nothing`.
"""
abstract_eval(ctx::LintContext, ex::Expr) = begin
    if isexpr(ex, :curly)
        objs = abstract_eval.(ctx, ex.args)
        if all(!isnull, objs)
            try
                Core.apply_type(get.(objs)...)
            catch
                nothing
            end
        else
            nothing
        end
    elseif isexpr(ex, :(.))
        head = ex.args[1]
        tail = ex.args[2].value
        obj = abstract_eval(ctx, head)
        if !isnull(obj)
            try
                getfield(get(obj), tail)
            catch
                nothing
            end
        else
            nothing
        end
    else
        nothing
    end
end

"""
    abstract_eval(ctx::LintContext, ex)

Return the literal embedded within a `Union{Any, Nothing}`.
"""
abstract_eval(ctx::LintContext, ex) = lexicalvalue(ex)
