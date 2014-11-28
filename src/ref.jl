function lintref( ex::Expr, ctx::LintContext )
    sub1 = ex.args[1]
    guesstype( ex, ctx ) # tickle the type checks on the expression
    if typeof(sub1)== Symbol
        # check to see if it's a type
        what = registersymboluse( sub1, ctx, false ) # :var, :DataType, or :Any
        if what == :Any
            str = string( sub1)
            #if !isupper( str[1] ) || length( str ) <= 2
            msg( ctx, 1, "Lint cannot determine if " * str * " is a DataType or not" )
            #end
        end
    else
        lintexpr(sub1, ctx)
    end
    for i=2:length(ex.args)
        lintexpr( ex.args[i], ctx )
    end
end
