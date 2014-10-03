function lintmacro( ex::Expr, ctx::LintContext )
    fname = ex.args[1].args[1]
    push!( ctx.callstack[end].macros, symbol( "@" * string(fname ) ) )
    push!( ctx.callstack[end].localarguments, Dict{ Symbol, Any }() )

    # grab the arguments. push a new stack, populate the new stack's argument fields and process the block
    stacktop = ctx.callstack[end]

    resolveArguments = (sube) -> begin
        if typeof( sube ) == Symbol
            stacktop.localarguments[end][sube]=VarInfo(ctx.line)
        #= # I don't think macro arguments use any of these
        elseif sube.head == :parameters
            for kw in sube.args
                resolveArguments( kw )
            end
        elseif sube.head == :(=) || sube.head == :kw
            resolveArguments( sube.args[1] )
        elseif sube.head == :(::)
            if length( sube.args ) > 1
                resolveArguments( sube.args[1] )
            end
        =#
        elseif sube.head == :(...)
            resolveArguments( sube.args[1])
        #= # macro definition inside another macro? highly unlikely
        elseif sube.head == :($)
            lintexpr( sube.args[1], ctx )
        =#
        else
            msg( ctx, 2, "Lint does not understand: " *string( sube ))
        end
    end

    for i = 2:length(ex.args[1].args)
        resolveArguments( ex.args[1].args[i])
    end

    ctx.macroLvl += 1
    lintexpr( ex.args[2], ctx )
    ctx.macroLvl -= 1
    pop!( ctx.callstack[end].localarguments )
end

function lintmacrocall( ex::Expr, ctx::LintContext )
    if ex.args[1] == symbol("@deprecate") || ex.args[1] == Expr( :(.), :Base, QuoteNode( symbol( "@deprecate" )))
        return
    end

    if ex.args[1] == symbol( "@lintpragma" )
        lintlintpragma( ex, ctx )
        return
    end

    if ex.args[1] == symbol( "@doc" ) # see Docile.jl
        if isexpr( ex.args[2], :(->) )
            lintexpr( ex.args[2].args[2], ctx ) # no need to lint the doc string
            return
        end
    end

    if ex.args[1] == symbol( "@gensym" )
        for i in 2:length( ex.args )
            if typeof( ex.args[i] ) == Symbol
                vi = VarInfo( ctx.line )
                ctx.callstack[end].localvars[end][ ex.args[i] ] = vi
            end
        end
        return
    end

    ctx.macrocallLvl = ctx.macrocallLvl + 1

    # AST for things like
    # @windows ? x : y
    # is very weird. This handles that.
    if length(ex.args) == 3 && ex.args[2] == :(?) && isexpr( ex.args[3], :(:) )
        for a in ex.args[3].args
            lintexpr( a, ctx )
        end
    else
        for i = 2:length(ex.args)
            lintexpr( ex.args[i], ctx )
        end
    end
    ctx.macrocallLvl = ctx.macrocallLvl - 1
end

