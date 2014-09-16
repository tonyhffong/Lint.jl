function lintlintpragma( ex::Expr, ctx::LintContext )
    if typeof( ex.args[2] ) <: String
        m = match( r"^((Print)|(Info)|(Warn)|(Error)) ((type)|(me)) +(.+)"s, ex.args[2] )
        if m != nothing
            action = m.captures[1]
            infotype = m.captures[6]
            rest = m.captures[9]
            if infotype == "type"
                var = parse( rest )
                if isexpr( var, :incomplete )
                    msg( ctx, 2, "Incomplete expression " * rest )
                    str = ""
                else
                    str = "typeof( " * rest * " ) == " * string( guesstype( var, ctx ) )
                end
            elseif infotype == "me"
                str = rest
            end

            if action == "Print"
                println( str )
            elseif action == "Info"
                msg( ctx, 0, str )
            elseif action == "Warn"
                msg( ctx, 1, str )
            else
                msg( ctx, 2, str )
            end
        else
            push!( ctx.callstack[end].pragmas, ex.args[2] )
        end
    else
        msg( ctx, 2, "lintpragma must be called using only string literals.")
    end
end
