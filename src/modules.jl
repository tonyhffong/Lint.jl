function lintmodule( ex::Expr, ctx::LintContext )
    push!( ctx.callstack[end].modules, ex.args[2] )
    push!( ctx.callstack, LintStack() )
    stacktop = ctx.callstack[end]
    stacktop.inModule = true
    stacktop.moduleName = ex.args[2]
    stacktop.isTop = true

    lintexpr( ex.args[3], ctx )

    undefs = setdiff( stacktop.exports, stacktop.types )
    undefs = setdiff( undefs, stacktop.functions )
    undefs = setdiff( undefs, stacktop.macros )
    undefs = setdiff( undefs, keys( stacktop.declglobs ) )
    undefs = setdiff( undefs, keys( stacktop.localvars[1] ) )
    undefs = setdiff( undefs, stacktop.imports )

    for sym in undefs
        msg( ctx, 2, "exporting undefined symbol " * string(sym))
    end
    pop!( ctx.callstack )
end

function lintusing( ex::Expr, ctx::LintContext )
    for s in ex.args
        if s != :(.)
            ctx.callstack[end].declglobs[ s ] = { :file => ctx.file, :line => ctx.line }
        end
    end
    if ex.args[1] != :(.)
        m = nothing
        path = join( map( string, ex.args ), "." )
        try
            eval( Main, ex )
            m = eval( Main, parse( path ) )
        end
        t = typeof( m )
        if t == Module
            for n in names( m )
                if !haskey( ctx.callstack[end].declglobs, n )
                    ctx.callstack[end].declglobs[ n ] = { :file => ctx.file, :line => ctx.line }
                end
            end

            if in( :lint_helper, names(m, true ) )
                if !haskey( ctx.callstack[end].linthelpers, path )
                    println( "found lint_helper in " * string(m))
                end
                ctx.callstack[end].linthelpers[ path ] = m.lint_helper
            end
        else
            msg( ctx, 1, string(path) * " doesn't eval into a Module")
        end
    end
end

function lintexport( ex::Expr, ctx::LintContext )
    for sym in ex.args
        if in(sym, ctx.callstack[end].exports )
            msg( ctx, 2, "duplicate exports of symbol " * string( sym ))
        else
            push!( ctx.callstack[end].exports, sym )
        end
    end
end

function linttoplevel( ex::Expr, ctx::LintContext )
    for a in ex.args
        if typeof(a)==Expr && a.head == :import
            if length(a.args) == 1 # just the module name
                union!( ctx.callstack[end].imports, names( eval( a.args[1] )))
            else
                push!( ctx.callstack[end].imports, a.args[2] )
            end
        end
    end
end

function lintimport( ex::Expr, ctx::LintContext; all::Bool = false )
    problem = false
    m = nothing
    lastpart = nothing
    try
        if ex.args[1] == :(.)
            path = string( ctx.callstack[end].moduleName )
            for i in 2:length(ex.args)
                path = path * "." * string(ex.args[i])
            end
            m = eval( parse( path ) )
            lastpart = ex.args[end]
        else
            lastpart = ex.args[end]
            m = eval( parse( join(ex.args, "." ) ) )
        end
    catch er
        problem = true
        println( er )
        println( ex )
    end
    if !problem
        t = typeof( m )
        if t == Module
            union!( ctx.callstack[end].imports, names( m, all ) )
        elseif typeof( lastpart  ) == Symbol
            push!( ctx.callstack[end].imports, lastpart )
            #push!( ctx.callstack[end].declglobs, lastport )
        end
    end
end

