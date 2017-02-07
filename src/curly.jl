
# curly A{a,b...} in the context of *using* a parametric type
# declaring a parametric function or parametric type are separately
# considered in lintfunction and linttype, respectively.

# contracts for common collections / type parametrized types
# TODO: Can we be more specific here? What about detecting contract?
const CURLY_CONTRACTS = Dict{Symbol, Any}(
    :Array  => (Type, Integer),
    :Dict   => (Type, Type),
    :Matrix => (Type,),
    :Set    => (Type,),
    :Type   => (Type,),
    :Val    => (Any,),
    :Vector => (Type,))

function lintcurly(ex::Expr, ctx::LintContext)
    head = ex.args[1]
    if head == :Ptr && length(ex.args) == 2 && ex.args[2] == :Void
        return
    end
    contract = get(CURLY_CONTRACTS, head, nothing)
    for i = 2:length(ex.args)
        a = ex.args[i]
        if isexpr(a, :parameters) # only used for Traits.jl, AFAIK
            continue # grandfathered. We worry about linting this later
        elseif isexpr(a, :($))
            continue # grandfathered
        else
            t = guesstype(a, ctx)
            if !(t <: Type || t == Symbol || isbits(t) || t == Any)
                msg(ctx, :W441, a, "probably illegal use inside curly")
            elseif contract != nothing
                if i - 1 > length(contract)
                    msg(ctx, :W446, head, "too many type parameters")
                elseif !(t <: contract[i - 1] || t == Any)
                    msg(ctx, :W447, t, "can't be #$(i-1) type parameter for $head;" *
                        "it should be of type $(contract[i-1])")
                end
            end
            lintexpr(a, ctx)
        end
    end
end
