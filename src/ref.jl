function lintref(ex::Expr, ctx::LintContext)
    sub1 = ex.args[1]
    guesstype(ex, ctx) # tickle the type checks on the expression
    lintexpr(sub1, ctx)
    sub1type = guesstype(sub1, ctx)
    for i=2:length(ex.args)
        if ex.args[i] == sub1
            if length(ex.args)==2 && sub1type <: Array{Int}
                msg(ctx, :I473, sub1, "value at position #$(i-1) is the referenced " *
                    "$(sub1). OK if it represents permutations")
            else # almost certain it's an error
                msg(ctx, :E434, sub1, "value at position #$(i-1) is the " *
                    "referenced $(sub1). Possible typo?")
            end
        end
        lintexpr(ex.args[i], ctx)
    end
end

function linttyped_vcat(ex::Expr, ctx::LintContext)
    lintref(ex, ctx)
end
