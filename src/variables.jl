function popVarScope( ctx::LintContext; checkargs::Bool=false )
    tmpline = ctx.line
    stacktop = ctx.callstack[end]
    unused = setdiff( keys(stacktop.localvars[end]), stacktop.localusedvars[end] )
    if ctx.quoteLvl == 0
        for v in unused
            if !pragmaexists( "Ignore unused " * utf8( v ), ctx ) && v != :_
                ctx.line = stacktop.localvars[end][ v ].line
                msg( ctx, :WARN, 341, v, "Local vars declared but not used: " * utf8( v ) )
            end
        end
        if checkargs
            unusedargs = setdiff( keys( stacktop.localarguments[end] ), stacktop.localusedargs[end] )
            for v in unusedargs
                if !pragmaexists( "Ignore unused " * utf8( v ), ctx ) && v != :_
                    ctx.line = stacktop.localarguments[end][ v ].line
                    msg( ctx, :INFO, 382, v, "argument declared but not used: " * utf8( v ) )
                end
            end
        end
    end

    union!( stacktop.oosvars, setdiff( keys( stacktop.localvars[end] ), keys( stacktop.localvars[1] )))
    pop!( stacktop.localvars )
    pop!( stacktop.localusedvars )
    ctx.line = tmpline
end

function pushVarScope( ctx::LintContext )
    push!( ctx.callstack[ end ].localvars, Dict{Symbol, Any}() )
    push!( ctx.callstack[ end ].localusedvars, Set{Symbol}() )
end

# returns
# :var - a non-DataType value
# :DataType
# :Any - don't know, could be either (with lint warnings, if strict)

# if strict == false, it won't generate lint warnings, just return :Any

function registersymboluse( sym::Symbol, ctx::LintContext, strict::Bool=true )
    stacktop = ctx.callstack[end]

    #println(sym)
    #println( stacktop.localvars )
    for i in length(stacktop.localvars):-1:1
        if haskey( stacktop.localvars[i], sym )
            push!( stacktop.localusedvars[i], sym )
            # TODO: This is not quite right. We need to check type
            # on the sym. If it's DataType, return :DataType
            # if Any, return :Any
            # otherwise, :var
            return :var
        end
    end

    for i in length(stacktop.localarguments):-1:1
        if haskey( stacktop.localarguments[i], sym )
            push!( stacktop.localusedargs[i], sym )
            # TODO: we need to check type
            return :var
        end
    end

    str = utf8(sym)
    if isupper( str[1] )
        @lintpragma( "Ignore incompatible type comparison" )
        t = nothing
        try
            tmp = eval( Main, sym )
            t = typeof(tmp)
        catch
            t = nothing
        end
        if t == DataType
            return :DataType
        elseif t != nothing
            return :var
        end
    end

    # a bunch of whitelist to just grandfather-in
    if in( sym, knowntypes )
        return :DataType
    end
    if in( sym, knownsyms )
        return :var
    end

    found = false
    ret = :var
    for i in length(ctx.callstack):-1:1
        if in( sym, ctx.callstack[i].types )
            found = true
            ret = :DataType
        elseif haskey( ctx.callstack[i].declglobs, sym ) ||
            in( sym, ctx.callstack[i].functions ) ||
            in( sym, ctx.callstack[i].modules ) ||
            in( sym, ctx.callstack[i].imports )
            found = true
        end

        if found
            # if in looking up variables we found global, from then
            # on we treat the variable as if we have had declared "global"
            # within the scope block
            if i != length(ctx.callstack) &&
                haskey( ctx.callstack[i].declglobs, sym )
                register_global(
                    ctx,
                    sym,
                    ctx.callstack[i].declglobs[sym]
                )
            end
            return ret
        end
    end

    maybefunc = nothing
    t = nothing
    try
        maybefunc = eval( Main, sym )
        t = typeof(maybefunc)
    catch
        t = nothing
    end
    if t == Function
        register_global(
            ctx,
            sym,
            @compat( Dict{Symbol,Any}( :file => ctx.file, :line => ctx.line ) )
        )
        return :var
    end

    if !strict
        return :Any
    end

    if pragmaexists( "Ignore use of undeclared variable " * utf8( sym ), ctx )
        return :Any
    end
    if ctx.quoteLvl == 0
        msg(ctx, :ERROR, 321, sym, "use of undeclared symbol " * utf8(sym))
    elseif ctx.isstaged
        msg(ctx, :INFO, 371, sym, "use of undeclared symbol " * utf8(sym))
    end
    return :Any
end

function lintglobal( ex::Expr, ctx::LintContext )
    for sym in ex.args
        if typeof(sym) == Symbol
            if !haskey( ctx.callstack[end].declglobs, sym)
                register_global(
                    ctx,
                    sym,
                    @compat( Dict{Symbol,Any}( :file=>ctx.file, :line=>ctx.line ) )
                )
            end
        elseif isexpr( sym, ASSIGN_OPS )
            lintassignment( sym, sym.head, ctx; isGlobal=true )
        else
            msg(ctx, :ERROR, 134, sym, "unknown global pattern $sym")
        end
    end
end

function lintlocal( ex::Expr, ctx::LintContext )
    n = length(ctx.callstack[end].localvars)
    for sube in ex.args
        if typeof(sube)==Symbol
            ctx.callstack[end].localvars[n][ sube ] = VarInfo( ctx.line )
            continue
        end
        if typeof(sube) != Expr
            msg(ctx, :ERROR, 135, sube, "local declaration $sube not understood by Lint")
            continue
        end
        if sube.head == :(=)
            lintassignment( sube, :(=), ctx; islocal = true )
        elseif sube.head == :(::)
            sym = sube.args[1]
            vi = VarInfo( ctx.line )
            try
                dt = eval( Main, sube.args[2] )
                if typeof( dt ) == DataType
                    vi.typeactual = dt
                else
                    vi.typeexpr = sube.args[2]
                end
            catch
                vi.typeexpr = sube.args[2]
            end
            ctx.callstack[end].localvars[n][ sym ] = vi
        end
    end
end

function resolveLHSsymbol( ex, syms::Array{Any,1}, ctx::LintContext, typeassert::Dict{Symbol,Any} )
    if typeof( ex ) == Symbol
        push!( syms, ex)
    elseif typeof( ex ) == Expr
        if ex.head == :(::)
            if typeof( ex.args[1]) == Symbol
                typeassert[ ex.args[1] ]=ex.args[2]
            end
            resolveLHSsymbol( ex.args[1], syms, ctx, typeassert )
        elseif ex.head == :tuple
            for s in ex.args
                resolveLHSsymbol( s, syms, ctx, typeassert )
            end
        elseif ex.head == :(.) ||   # a.b = something
            ex.head == :ref ||      # a[b] = something
            ex.head == :($)         # :( $(esc(name)) = something )
            push!( syms, ex )
            lintexpr( ex, ctx )
            return
        else
            msg( ctx, :INFO, 171, ex, "LHS in assignment not understood by Lint. please check: $ex" )
        end
    else
        msg( ctx, :INFO, 171, ex, "LHS in assignment not understood by Lint. please check: $ex" )
    end
end

function lintassignment( ex::Expr, assign_ops::Symbol, ctx::LintContext; islocal = false, isConst=false, isGlobal=false, isForLoop=false ) # is it a local decl & assignment?
    lintexpr( ex.args[2], ctx )

    syms = Any[]
    typeassert = Dict{ Symbol, Any }()
    resolveLHSsymbol( ex.args[1], syms, ctx, typeassert )
    tuplelen = length( syms )
    rhstype = guesstype( ex.args[2], ctx )

    if isForLoop
        if rhstype <: Number
            msg( ctx, :INFO, 672, "iteration works for a number but it may be a typo" )
        end

        if rhstype <: Tuple
            rhstype = Any
        elseif rhstype <: Set || rhstype <: Array || rhstype <: Range || rhstype <: Enumerate
            rhstype = eltype( rhstype )
        elseif rhstype <: Associative
            @lintpragma( "Ignore unstable type variable rhstype" )
            if VERSION < v"0.4.0-dev+4139"
                rhstype = ( keytype( rhstype ), valuetype( rhstype ) )
            else
                rhstype = Tuple{ keytype( rhstype ), valuetype( rhstype ) }
            end
        end

        if VERSION < v"0.4.0-dev+4139"
            if rhstype <: Tuple && length( rhstype ) != tuplelen
                msg( ctx, :INFO, 474, rhstype, "iteration generates tuples of $rhstype. " *
                    "N of variables used: $tuplelen" )
            end
        else
            if rhstype <: Tuple && length( rhstype.parameters ) != tuplelen
                msg( ctx, :INFO, 474, rhstype, "iteration generates tuples of $rhstype. " *
                    "N of variables used: $tuplelen" )
            end
        end
    end

    if VERSION < v"0.4.0-dev+4139"
        if typeof( rhstype ) != Symbol && rhstype <: Tuple && length( rhstype ) != tuplelen && !isForLoop
            if length( syms ) > 1
                msg( ctx, :ERROR, 418, rhstype, "RHS is a tuple of $rhstype. N of " *
                    "variables used: $tuplelen" )
            end
        end
    else
        if typeof(rhstype) != Symbol && rhstype <: Tuple && length( rhstype.parameters ) != tuplelen && !isForLoop
            if tuplelen > 1
                msg( ctx, :ERROR, 418, rhstype, "RHS is a tuple of $rhstype. N of " *
                    "variables used: $tuplelen" )
            end
        end
    end

    for (symidx, s) in enumerate( syms )
        if typeof( s ) != Symbol # a.b or a[b]
            if isexpr( s, [ :(.), :ref ] )
                containertype = guesstype( s.args[1], ctx )
                if containertype != Any && typeof( containertype ) == DataType && !containertype.mutable
                    msg( ctx, :ERROR, 525, s.args[1], "$(s.args[1]) is of an immutable type $(containertype)" )
                end
            end

            continue
        end
        if string(s) == ctx.scope && !islocal
            msg( ctx, :WARN, 355, ctx.scope, "variable $(ctx.scope) == function name" )
        end
        if s == :call
            msg(ctx, :ERROR, 332, s, "$(s) should not be used as a variable name")
        elseif in( s, knownsyms )
            if in( s, [ :e, :pi, :eu, :catalan, :eulergamma, :golden, :π, :γ, :φ ] )
                if ctx.file != "constants.jl"
                    msg( ctx, :WARN, 351, s, "you are redefining a mathematical constant $(s)" )
                end
            else
                msg( ctx, :WARN, 356, s, "$s as a local variable might cause " *
                    "confusion with a synonymous export from Base" )
            end
        end

        # +=, -=, *=, etc.
        if ex.head != :(=)
            registersymboluse( s, ctx )
        end
        vi = VarInfo( ctx.line )
        #@lintpragma( "Ignore incompatible type comparison" )
        if VERSION < v"0.4.0-dev+4139"
            if rhstype == Any || length( syms ) == 1
                rhst = rhstype
            elseif rhstype <: Tuple && length( rhstype ) == length( syms )
                @lintpragma( "DataType is a container type")
                rhst = rhstype[ symidx ]
            else
                rhst = Any
            end
        else
            if rhstype == Any || length( syms ) == 1
                rhst = rhstype
            elseif rhstype <: Tuple && length( rhstype.parameters ) == length( syms )
                rhst = rhstype.parameters[ symidx ]
            else
                rhst = Any
            end
        end
        try
            if haskey( typeassert, s )
                dt = eval( Main, typeassert[ s ] )
                if typeof( dt ) == DataType
                    vi.typeactual = dt
                    if !isAnyOrTupleAny( dt ) && !isAnyOrTupleAny( rhstype ) && !( rhstype <: dt )
                        msg( ctx, :INFO, 572, "assert $(s) type= $(dt) but assign a " *
                            "value of $(rhstype)" )
                    end
                else
                    vi.typeexpr = typeassert[ s ]
                end
            elseif rhst != Any && !isForLoop
                vi.typeactual = rhst
            end
        catch er
            msg( ctx, :WARN, 251, s, "$(er); $(ex); Symbol=$(s); rhstype=$(rhst)" )
            if haskey( typeassert, s )
                vi.typeexpr = typeassert[s]
            end
        end

        if islocal
            ctx.callstack[end].localvars[end][ s ] = vi
        else # it's not explicitly local, but it could be!
            found = false
            for i in length(ctx.callstack[end].localvars):-1:1
                if haskey( ctx.callstack[end].localvars[i], s )
                    found = true
                    prevvi = ctx.callstack[end].localvars[i][s]
                    if typeof( vi.typeactual ) <: DataType && typeof( prevvi.typeactual ) <: DataType &&
                        vi.typeactual <: Number && prevvi.typeactual <: Number && assign_ops != :(=)
                        if length( prevvi.typeactual.parameters ) == 0
                        else
                        end
                        continue
                    elseif typeof( vi.typeactual ) <: DataType && typeof( prevvi.typeactual ) <: DataType &&
                        vi.typeactual <: Number && prevvi.typeactual <: Array && assign_ops != :(=)

                        continue
                    elseif !isAnyOrTupleAny( vi.typeactual ) && typeof( vi.typeactual ) != Symbol && !( vi.typeactual <: prevvi.typeactual ) &&
                        !( vi.typeactual <: AbstractString && prevvi.typeactual <: vi.typeactual ) &&
                        !pragmaexists( "Ignore unstable type variable $(s)", ctx )
                        msg( ctx, :WARN, 545, s, "previously used $(s) has apparent type " *
                            "$(prevvi.typeactual), but now assigned $(vi.typeactual)" )
                    end
                    ctx.callstack[end].localvars[i][ s] = vi
                end
            end

            if !found && in( s, ctx.callstack[end].oosvars )
                msg( ctx, :INFO, 482, s, "$(s) has been used in a local scope. Improve " *
                    "readability by using 'local' or another name")
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
                        msg( ctx, :INFO, 391, s, "$(s) is also a global, from :  $(src); Please check" )
                        break;
                    end
                end
            end

            if !found
                ctx.callstack[end].localvars[1][ s ] = vi
            end
        end
        if isGlobal || isConst || (ctx.functionLvl + ctx.macroLvl == 0 && ctx.callstack[end].isTop)
            register_global(
                ctx,
                s,
                @compat( Dict{Symbol,Any}( :file => ctx.file, :line => ctx.line ) )
            )
        end
    end
end

