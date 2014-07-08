function linttype( ex::Expr, ctx::LintContext )
    if typeof( ex.args[2] ) == Expr && ex.args[2].head == :($) && typeof( ex.args[2].args[1] ) == Symbol
        registersymboluse( ex.args[2].args[1], ctx )
    end
    if typeof( ex.args[2] ) == Symbol
        push!( ctx.callstack[end].types, ex.args[2] )
    elseif typeof( ex.args[2] ) == Expr && ex.args[2].head == :curly
        for i in 2:length(ex.args[2].args)
            adt= ex.args[2].args[i]
            if typeof( adt )== Symbol && in( adt, knowntypes )
                msg( ctx, 2, "You mean {T<:"*string( adt )*"}? You are introducting it as a new name for an algebric data type, unrelated to the type " * string(adt))
            elseif typeof(adt)==Expr && adt.head == :(<:)
                temptype = adt.args[1]
                typeconstraint = adt.args[2]
                if in( temptype, knowntypes )
                    msg( ctx, 2, "You should use {T<:...} instead of a known type " * string(temptype) * " in parametric data type")
                end
                if in( typeconstraint, knowntypes )
                    dt = eval( typeconstraint )
                    if typeof( dt ) == DataType && isleaftype( dt )
                        msg( ctx, 2, string( dt )* " is a leaf type. As a type constraint it makes no sense in " * string(adt) )
                    end
                end
                push!( ctx.callstack[end].types, ex.args[2].args[i] )
            end
        end
    elseif typeof( ex.args[2] ) == Expr && ex.args[2].head == :(<:)
        if typeof( ex.args[2].args[1] ) == Symbol
            push!( ctx.callstack[end].types, ex.args[2].args[1] )
        elseif typeof( ex.args[2].args[1] )==Expr && ex.args[2].args[1].head == :curly
            adt = ex.args[2].args[1].args[2]
            if typeof( adt )== Symbol
                if in( adt, knowntypes )
                    msg( ctx, 2, "You mean {T<:"*string( adt )*"}? You are introducting it as a new name for an algebric data type, unrelated to the type " * string(adt))
                else
                    push!( ctx.callstack[end].types, adt )
                end
            elseif adt.head == :(<:)
                temptype = adt.args[1]
                typeconstraint = adt.args[2]
                if in( temptype, knowntypes )
                    msg( ctx, 2, "You should use {T<:...} instead of a known type " * string(temptype) * " in parametric data type")
                end
                if in( typeconstraint, knowntypes )
                    dt = eval( typeconstraint )
                    if typeof( dt ) == DataType && isleaftype( dt )
                        msg( ctx, 2, string( dt )* " is a leaf type. As a type constraint it makes no sense in " * string(adt) )
                    end
                end
                push!( ctx.callstack[end].types, ex.args[2].args[1].args[1] )
            end
        end
    end
end

function linttypealias( ex::Expr, ctx::LintContext )
    if typeof(ex.args[1])== Symbol
        push!( ctx.callstack[end].types, ex.args[1])
    elseif typeof( ex.args[1] ) == Expr && ex.args[1].head == :curly
        push!( ctx.callstack[end].types, ex.args[1].args[1] )
    end
end

function lintabstract( ex::Expr, ctx::LintContext )
    if typeof( ex.args[1] ) == Symbol
        push!( ctx.callstack[end].types, ex.args[1] )
    elseif typeof( ex.args[1] ) == Expr && ex.args[1].head == :curly
        push!( ctx.callstack[end].types, ex.args[1].args[1] )
    elseif typeof( ex.args[1] ) == Expr && ex.args[1].head == :(<:)
        if typeof( ex.args[1].args[1] ) == Symbol
            push!( ctx.callstack[end].types, ex.args[1].args[1] )
        elseif typeof( ex.args[1].args[1] )==Expr && ex.args[1].args[1].head == :curly
            push!( ctx.callstack[end].types, ex.args[1].args[1].args[1] )
        end
    end
end
