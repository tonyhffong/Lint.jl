function popVarScope( ctx::LintContext )
    stacktop = ctx.callstack[end]
    unused = setdiff( keys(stacktop.localvars[end]), stacktop.localusedvars[end] )
    for v in unused
        ctx.line = stacktop.localvars[end][ v ]
        msg( ctx, 1, "Local vars declared but not used: " * string( v ) )
    end

    union!( stacktop.oosvars, setdiff( keys( stacktop.localvars[end] ), keys( stacktop.localvars[1] )))
    pop!( stacktop.localvars )
    pop!( stacktop.localusedvars )
end

function pushVarScope( ctx::LintContext )
    push!( ctx.callstack[ end ].localvars, Dict{Symbol, Any}() )
    push!( ctx.callstack[ end ].localusedvars, Set{Symbol}() )
end

function registersymboluse( sym::Symbol, ctx::LintContext )
    global knownsyms
    stacktop = ctx.callstack[end]

    str = string(sym)

    if isupper( str[1] )
        t = nothing
        try
            tmp = eval( sym )
            t = typeof(tmp)
        catch
            t = nothing
        end
        if t == DataType
            return
        end
    end

    #println(sym)
    #println( stacktop.localvars )
    found = false
    for i in length(stacktop.localvars):-1:1
        if haskey( stacktop.localvars[i], sym )
            push!( stacktop.localusedvars[i], sym )
            found = true
            break
        end
    end
    if !found
        for i in length(stacktop.localarguments):-1:1
            if haskey( stacktop.localarguments[i], sym )
                found = true
                break
            end
        end
    end

    # a bunch of whitelist to just grandfather-in
    if !found && in( sym, knownsyms )
        return
    end

    if !found
        for i in length(ctx.callstack):-1:1
            found = haskey( ctx.callstack[i].declglobs, sym ) ||
                in( sym, ctx.callstack[i].functions ) ||
                in( sym, ctx.callstack[i].types ) ||
                in( sym, ctx.callstack[i].modules ) ||
                in( sym, ctx.callstack[i].imports )

            if found
                # if in looking up variables we found global, from then
                # on we treat the variable as if we have had declared "global"
                # within the scope block
                if i != length(ctx.callstack) &&
                    haskey( ctx.callstack[i].declglobs, sym )
                    ctx.callstack[end].declglobs[ sym ] = ctx.callstack[i].declglobs[sym]
                end
                break
            end
        end
    end

    if !found
        maybefunc = nothing
        t = nothing
        try
            maybefunc = eval( sym )
            t = typeof(maybefunc)
        catch
            t = nothing
        end
        found = (t == Function)
        if found
            ctx.callstack[end].declglobs[ sym ] = { :file => ctx.file, :line => ctx.line }
        end
    end

    if !found
        msg( ctx, 2, "Use of undeclared symbol " *string(sym))
    end
end

function lintglobal( ex::Expr, ctx::LintContext )
    for sym in ex.args
        if typeof(sym) == Symbol
            if !haskey( ctx.callstack[end].declglobs, sym)
                ctx.callstack[end].declglobs[ sym ] = { :file=>ctx.file, :line=>ctx.line }
            end
        elseif isexpr( sym, ASSIGN_OPS )
            lintassignment( sym, ctx; isGlobal=true )
        else
            msg( ctx, 2, "unknown global pattern " * string(sym))
        end
    end
end

function lintlocal( ex::Expr, ctx::LintContext )
    n = length(ctx.callstack[end].localvars)
    for sube in ex.args
        if typeof(sube)==Symbol
            ctx.callstack[end].localvars[n][ sube ] = ctx.line
            continue
        end
        if typeof(sube) != Expr
            msg( ctx, 2, "local declaration not understood by lint. please check")
            continue
        end
        if sube.head == :(=)
            lintassignment( sube, ctx; islocal = true )
        elseif sube.head == :(::)
            sym = sube.args[1]
            ctx.callstack[end].localvars[n][ sym ] = ctx.line
        end
    end
end

function resolveLHSsymbol( ex, syms::Array{Symbol,1}, ctx::LintContext )
    if typeof( ex ) == Symbol
        push!( syms, ex)
    elseif ex.head == :(::)
        resolveLHSsymbol( ex.args[1], syms, ctx )
    elseif ex.head == :tuple
        for s in ex.args
            resolveLHSsymbol( s, syms, ctx )
        end
    elseif ex.head == :(.) ||   # a.b = something
        ex.head == :ref ||      # a[b] = something
        ex.head == :($)         # :( $(esc(name)) = something )
        lintexpr( ex.args[1], ctx )
        return
    else
        msg( ctx, 2, "LHS in assignment not understood by Lint. please check: " * string(ex) )
    end
end

function lintassignment( ex::Expr, ctx::LintContext; islocal = false, isConst=false, isGlobal=false, isForLoop=false ) # is it a local decl & assignment?
    lintexpr( ex.args[2], ctx )

    syms = Symbol[]
    resolveLHSsymbol( ex.args[1], syms, ctx )

    if isForLoop && length(syms)==1 && isexpr( ex.args[2], [:dict, :typed_dict] )
        msg( ctx, 0, "Typically iteration over dictionary uses a (k,v) tuple. Here only one variable is used." )
    end

    for s in syms
        if in( s, [ :e, :pi, :eu, :catalan, :eulergamma, :golden, :π, :γ, :φ ] )
            msg( ctx, 1, "You are redefining a mathematical constant " * string(s) )
        end

        if islocal
            ctx.callstack[end].localvars[end][ s ] = ctx.line
        else # it's not explicitly local, but it could be!
            found = false
            for i in length(ctx.callstack[end].localvars):-1:1
                if haskey( ctx.callstack[end].localvars[i], s )
                    found = true
                    ctx.callstack[end].localvars[i][ s] = ctx.line
                end
            end

            if !found && in( s, ctx.callstack[end].oosvars )
                msg( ctx, 0, string(s) * " has been used in a local scope. Improve readability by using 'local' or another name.")
            end

            if !found && !isGlobal && !haskey( ctx.callstack[end].declglobs, s )
                for i in length(ctx.callstack)-1:-1:1
                    if haskey( ctx.callstack[i].declglobs, s ) &&
                        length(string(s)) > 4 &&
                        !in( s, [ :value, :index, :fname, :fargs ] )
                        src = string(ctx.callstack[i].declglobs[s] )
                        l = split( src, "\n" )
                        splice!( l, 1)
                        src = join( l, "\n" )
                        msg( ctx, 0, string( s ) * " is also a global, from \n" * src * "\nPlease check." )
                        break;
                    end
                end
            end

            if !found
                ctx.callstack[end].localvars[1][ s ] = ctx.line
            end
        end
        if isGlobal || isConst || (ctx.functionLvl + ctx.macroLvl == 0 && ctx.callstack[end].isTop)
            ctx.callstack[end].declglobs[ s ] = { :file => ctx.file, :line => ctx.line }
        end
    end
end

