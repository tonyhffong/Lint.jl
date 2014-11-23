
# curly A{a,b...} in the context of *using* a parametric type
# declaring a parametric function or parametric type are separately
# considered in lintfunction and linttype, respectively.

function lintcurly( ex::Expr, ctx::LintContext )
    if ex.args[1] == :Ptr && length(ex.args)==2 && ex.args[2] == :Void
        return
    end
    for i = 2:length( ex.args )
        a = ex.args[i]
        if isexpr( a, :parameters ) # only used for Traits.jl, AFAIK
            continue # grandfathered. We worry about linting this later
        elseif isexpr( a, :(<:) )
            if typeof( a.args[1] ) != Symbol && !isexpr( a.args[2], :($) )
                msg( ctx, 2, "Left of <: should be just a symbol inside curly" )
            end
        elseif isexpr( a, :($) )
            continue # grandfathered
        elseif typeof( a ) == QuoteNode || isexpr( a, :quote )
            msg( ctx, 1, "Probably illegal use of " * string(a) * " inside curly.")
        else
            t = guesstype( a, ctx )
            if t == Symbol || t != Any && t != () && typeof( t ) != DataType && typeof( t ) != (DataType,) && !( t <: Integer )
                msg( ctx, 1, "Probably illegal use of " * string(a) * " inside curly.")
            end
            lintexpr( a, ctx )
        end
    end
end
