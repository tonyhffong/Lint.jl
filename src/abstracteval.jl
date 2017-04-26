"""
    abstract_eval(ctx::LintContext, ex) :: Nullable

Like `eval`, but does it in the current context and without any dynamism.
Returns `Nullable()` if the result can't be evaluated.
"""
abstract_eval(ctx::LintContext, ex::Symbol) =
    flatten(BROADCAST(extractobject, lookup(ctx, ex)))

"""
    abstract_eval(ctx::LintContext, ex::Expr) :: Nullable

If the given expression is curly, and each component of the curly is a constant
object in the given `ctx`, construct the object `x` as would have been done in
the program itself, and return `Nullable(x)`.

Otherwise, if the given expression is `foo.bar`, and `foo` is a standard
library object with attribute `bar`, then construct `foo.bar` as would be done
in the program itself and return it.

Otherwise, return `Nullable()`.
"""
abstract_eval(ctx::LintContext, ex::Expr) = begin
    if isexpr(ex, :curly)
        # TODO: when 0.5 support dropped, remove [...] around ctx
        objs = abstract_eval.([ctx], ex.args)
        if all(!isnull, objs)
            try
                Nullable(Core.apply_type(get.(objs)...))
            catch
                Nullable()
            end
        else
            Nullable()
        end
    elseif isexpr(ex, :(.))
        head = ex.args[1]
        tail = ex.args[2].value
        obj = abstract_eval(ctx, head)
        if !isnull(obj)
            try
                Nullable(getfield(get(obj), tail))
            catch
                Nullable()
            end
        else
            Nullable()
        end
    else
        Nullable()
    end
end

"""
    abstract_eval(ctx::LintContext, ex)

Return the literal embedded within a `Nullable{Any}`.
"""
abstract_eval(ctx::LintContext, ex) = lexicalvalue(ex)
