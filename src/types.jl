# type definition lint code

function linttype( ex::Expr, ctx::LintContext )
    if ctx.macroLvl ==0 && ctx.functionLvl == 0
        pushcallstack( ctx )
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
                if typefound && adt != :T
                    msg( ctx, 2, "You mean {T<:"*string( adt )*"}? You are introducing it as a new name for an algebric data type, unrelated to the type " * string(adt))
                end
                push!( ctx.callstack[end].types, adt )
            elseif isexpr( adt, :(<:) )
                temptype = adt.args[1]
                typeconstraint = adt.args[2]

                if temptype != :T
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

    fields = Any[]
    funcs = Any[]

    for def in ex.args[3].args
        if typeof( def ) == LineNumberNode
            ctx.line = def.line-1
        elseif typeof( def ) == Symbol
            # it means Any, probably not a very efficient choice
            if !pragmaexists( "Ignore untyped field " * string( def ), ctx, deep=false )
                msg( ctx, 0, "A type is not given to the field " * string( def ) * ", which can be slow." )
            end
            push!( fields, ( def, Any ))
        elseif isexpr( def, :macrocall ) && def.args[1] == symbol( "@lintpragma" )
            lintlintpragma( def, ctx )
        elseif isexpr( def, :call ) && def.args[1] == symbol( "lintpragma" )
            lintlintpragma( def, ctx )
            msg( ctx,2, "Use @lintpragma macro inside type declaration" )
        elseif def.head == :(::)
            if isexpr( def.args[2], :curly ) && def.args[2].args[1] == :Array && length( def.args[2].args ) <= 2 &&
                !pragmaexists( "Ignore dimensionless array field " * string( def.args[1] ), ctx, deep=false )
                msg( ctx, 0, "Array field " * string( def.args[1] ) * " has no dimension, which can be slow" )
            end
            push!( fields, (def.args[1], def.args[2]) )
        elseif def.head == :(=) && isexpr( def.args[1], :call ) || def.head == :function
            # curly bracket doesn't belong here. catch it first before linting the rest of the function body
            if def.args[1].head == :tuple
                # if julia supports anonymous constructor syntactic sugar, remove this, and make sure ctx.scope is type name
                msg( ctx, 2, "What is an anonymous function doing inside a type definition?")
            elseif isexpr( def.args[1].args[1], :curly )
                msg( ctx, 2, "Parametric constructors (with curly brackets) should not be inner constructors. Define them outside type definition.")
            end
            push!( funcs, ( def, ctx.line ) )
        end
    end

    if typename != symbol( "" )
        ctx.callstack[end-1].typefields[ typename ] = fields
    end

    for f in funcs
        ctx.line = f[2]
        lintfunction( f[1], ctx; ctorType = typename )
    end

    if ctx.macroLvl ==0 && ctx.functionLvl == 0
        popcallstack( ctx )
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

function lintbitstype( ex::Expr, ctx::LintContext )
    if typeof( ex.args[2] ) != Symbol
        msg( ctx, 2, "bitstype needs its 2nd argument to be a new type symbol")
    else
        push!( ctx.callstack[end].types, ex.args[2] )
    end
end
