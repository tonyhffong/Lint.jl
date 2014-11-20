function lintref( ex::Expr, ctx::LintContext )
    sub1 = ex.args[1]
    guesstype( ex, ctx ) # tickle the type checks on the expression
    if typeof(sub1)== Symbol
        # check to see if it's a type
        str = string( sub1)
        if !isupper( str[1] )
            registersymboluse( sub1,ctx )
        end
    else
        lintexpr(sub1, ctx)
    end
    for i=2:length(ex.args)
        lintexpr( ex.args[i], ctx )
    end
end
