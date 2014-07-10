# type definition lint code

function linttype( ex::Expr, ctx::LintContext )
    if typeof( ex.args[2] ) == Symbol
        push!( ctx.callstack[end].types, ex.args[2] )
    elseif isexpr( ex.args[2], :($) ) && typeof( ex.args[2].args[1] ) == Symbol
        registersymboluse( ex.args[2].args[1], ctx )
    elseif isexpr( ex.args[2], :curly )
        for i in 2:length(ex.args[2].args)
            adt= ex.args[2].args[i]
            if typeof( adt )== Symbol && in( adt, knowntypes )
                msg( ctx, 2, "You mean {T<:"*string( adt )*"}? You are introducing it as a new name for an algebric data type, unrelated to the type " * string(adt))
            elseif isexpr( adt, :(<:) )
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
    elseif isexpr( ex.args[2], :(<:) )
        if typeof( ex.args[2].args[1] ) == Symbol
            push!( ctx.callstack[end].types, ex.args[2].args[1] )
        elseif isexpr( ex.args[2].args[1], :curly )
            adt = ex.args[2].args[1].args[2]
            if typeof( adt )== Symbol
                if in( adt, knowntypes )
                    msg( ctx, 2, "You mean {T<:"*string( adt )*"}? You are introducing it as a new name for an algebric data type, unrelated to the type " * string(adt))
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

    for def in ex.args[3].args
        if typeof( def ) == LineNumberNode
            ctx.line = def.line
        elseif def.head == :line
            ctx.line = def.args[1]
        elseif def.head == :(::)
        elseif def.head == :(=) && isexpr( def.args[1], :call )
            lintfunction( def, ctx )
        elseif def.head == :function
            lintfunction( def, ctx )
        end
    end
end

function linttypealias( ex::Expr, ctx::LintContext )
    if typeof(ex.args[1])== Symbol
        push!( ctx.callstack[end].types, ex.args[1])
    elseif isexpr( ex.args[1], :curly )
        push!( ctx.callstack[end].types, ex.args[1].args[1] )
    end
end

function lintabstract( ex::Expr, ctx::LintContext )
    if typeof( ex.args[1] ) == Symbol
        push!( ctx.callstack[end].types, ex.args[1] )
    elseif isexpr( ex.args[1], :curly )
        push!( ctx.callstack[end].types, ex.args[1].args[1] )
    elseif isexpr( ex.args[1], :(<:) )
        if typeof( ex.args[1].args[1] ) == Symbol
            push!( ctx.callstack[end].types, ex.args[1].args[1] )
        elseif isexpr( ex.args[1].args[1], :curly )
            push!( ctx.callstack[end].types, ex.args[1].args[1].args[1] )
        end
    end
end
