# type definition lint code

function linttype( ex::Expr, ctx::LintContext )
    if ctx.macroLvl ==0 && ctx.functionLvl == 0
        push!( ctx.callstack, LintStack() )
    end

    processCurly = (sube)->begin
        for i in 2:length(sube.args)
            adt= sube.args[i]
            if typeof( adt )== Symbol
                typefound = in( adt, knowntypes )
                if !typefound
                    for j in 1:length(ctx.callstack)
                        if in( adt, ctx.callstack[j].types )
                            typefound = true
                            break
                        end
                    end
                end
                if typefound
                    msg( ctx, 2, "You mean {T<:"*string( adt )*"}? You are introducing it as a new name for an algebric data type, unrelated to the type " * string(adt))
                else
                    push!( ctx.callstack[end].types, adt )
                end
            elseif isexpr( adt, :(<:) )
                temptype = adt.args[1]
                typeconstraint = adt.args[2]

                typefound = in( temptype, knowntypes )
                if !typefound
                    for j in 1:length(ctx.callstack)
                        if in( temptype, ctx.callstack[j].types )
                            typefound = true
                            break
                        end
                    end
                end
                if typefound
                    msg( ctx, 2, "You should use {T<:...} instead of a known type " * string(temptype) * " in parametric data type")
                end
                if in( typeconstraint, knowntypes )
                    dt = eval( typeconstraint )
                    if typeof( dt ) == DataType && isleaftype( dt )
                        msg( ctx, 2, string( dt )* " is a leaf type. As a type constraint it makes no sense in " * string(adt) )
                    end
                end
                push!( ctx.callstack[end].types, temptype )
            end
        end
    end

    typename = symbol( "" )
    if typeof( ex.args[2] ) == Symbol
        typename = ex.args[2]
    elseif isexpr( ex.args[2], :($) ) && typeof( ex.args[2].args[1] ) == Symbol
        registersymboluse( ex.args[2].args[1], ctx )
    elseif isexpr( ex.args[2], :curly )
        typename = ex.args[2].args[1]
        processCurly( ex.args[2] )
    elseif isexpr( ex.args[2], :(<:) )
        if typeof( ex.args[2].args[1] ) == Symbol
            typename = ex.args[2].args[1]
        elseif isexpr( ex.args[2].args[1], :curly )
            typename = ex.args[2].args[1].args[1]
            processCurly( ex.args[2].args[1] )
        end
    end
    if typename != symbol( "" )
        push!( ctx.callstack[end-1].types, typename )
    end

    for def in ex.args[3].args
        if typeof( def ) == LineNumberNode
            ctx.line = def.line
        elseif typeof( def ) == Symbol
            # it means Any, probably not a very efficient choice
            if !in( "Ignore untyped field " * string( def ), ctx.callstack[end].pragmas )
                msg( ctx, 0, "A type is not given to the field " * string( def ) * ", which can be slow." )
            end
        elseif isexpr( def, :macrocall ) && def.args[1] == symbol( "@lintpragma" )
            lintlintpragma( def, ctx )
        elseif isexpr( def, :call ) && def.args[1] == symbol( "lintpragma" )
            lintlintpragma( def, ctx )
            msg( ctx,2, "Use @lintpragma macro inside type declaration" )
        elseif def.head == :(::)
            if isexpr( def.args[2], :curly ) && def.args[2].args[1] == :Array && length( def.args[2].args ) <= 2 &&
                !in( "Ignore dimensionless array field " * string( def.args[1] ), ctx.callstack[end].pragmas )
                msg( ctx, 0, "Array field " * string( def.args[1] ) * " has no dimension, which can be slow" )
            end
        elseif def.head == :(=) && isexpr( def.args[1], :call )
            lintfunction( def, ctx; ctorType = typename )
        elseif def.head == :function
            lintfunction( def, ctx; ctorType = typename )
        end
    end
    if ctx.macroLvl ==0 && ctx.functionLvl == 0
        pop!( ctx.callstack )
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
