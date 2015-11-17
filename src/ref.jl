function lintref( ex::Expr, ctx::LintContext )
    sub1 = ex.args[1]
    guesstype( ex, ctx ) # tickle the type checks on the expression
    if typeof(sub1)== Symbol
        # check to see if it's a type
        what = registersymboluse( sub1, ctx, false ) # :var, :DataType, or :Any
        if what == :Any
            str = string( sub1)
            #if !isupper( str[1] ) || length( str ) <= 2
            msg( ctx, :WARN, "Lint cannot determine if " * str * " is a DataType or not" )
            #end
        end
    else
        lintexpr(sub1, ctx)
    end
    sub1type = guesstype( sub1, ctx )
    for i=2:length(ex.args)
        if ex.args[i] == sub1
            if length(ex.args)==2 && sub1type <: Array{Int}
                msg( ctx, :INFO, "Value at position #" * string( i-1) * " is the referenced " * string(sub1) * ". OK if it represents permutations" )
            else # almost certain it's an error
                msg( ctx, :ERROR, "Value at position #" * string( i-1) * " is the referenced " * string(sub1) * ". Possible typo?" )
            end
        end
        lintexpr( ex.args[i], ctx )
    end
end

function linttyped_vcat( ex::Expr, ctx::LintContext )
    lintref( ex, ctx )
end
