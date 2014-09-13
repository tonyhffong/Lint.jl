function popVarScope( ctx::LintContext )
    stacktop = ctx.callstack[end]
    unused = setdiff( keys(stacktop.localvars[end]), stacktop.localusedvars[end] )
    for v in unused
        if !in( "Ignore unused " * string( v ), stacktop.pragmas )
            ctx.line = stacktop.localvars[end][ v ].line
            msg( ctx, 1, "Local vars declared but not used: " * string( v ) )
        end
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
            msg( ctx, 0, "unknown global pattern " * string(sym))
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
            msg( ctx, 2, "local declaration not understood by lint. please check")
            continue
        end
        if sube.head == :(=)
            lintassignment( sube, ctx; islocal = true )
        elseif sube.head == :(::)
            sym = sube.args[1]
            vi = VarInfo( ctx.line )
            try
                dt = eval( sube.args[2] )
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

function resolveLHSsymbol( ex, syms::Array{Symbol,1}, ctx::LintContext, typeassert::Dict{Symbol,Any} )
    if typeof( ex ) == Symbol
        push!( syms, ex)
    elseif ex.head == :(::)
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
        lintexpr( ex.args[1], ctx )
        return
    else
        msg( ctx, 0, "LHS in assignment not understood by Lint. please check: " * string(ex) )
    end
end

function guesstype( ex::Any, ctx::LintContext )
    t = typeof( ex )
    if t <: Number || t <: String
        return t
    end
    if t==Symbol # check if we have seen it
        stacktop = ctx.callstack[end]
        sym = ex
        for i in length(stacktop.localvars):-1:1
            if haskey( stacktop.localvars[i], sym )
                return stacktop.localvars[i][sym].typeactual
            end
        end
        for i in length(stacktop.localarguments):-1:1
            if haskey( stacktop.localarguments[i], sym )
                return stacktop.localarguments[i][sym].typeactual
            end
        end
        return Any
    end

    if t == QuoteNode
        return typeof( ex.value )
    end

    if t != Expr
        return Any
    end

    if isexpr( ex, :call ) && ex.args[1] == :convert && typeof( ex.args[2] ) == Symbol
        ret = Any
        try
            ret = eval( ex.args[2] )
        end
        return ret
    end

    if isexpr( ex, :call )
        fn = ex.args[1]
        if fn == :int
            return Int
        elseif fn == :int8
            return Int8
        elseif fn == :int16
            return Int16
        elseif fn == :int32
            return Int32
        elseif fn == :int64
            return Int64
        elseif fn == :float
            return Float64
        elseif fn == :Complex
            return Complex
        elseif fn == :Rational
            return Rational
        end
    end

    if isexpr( ex, :macrocall ) && ex.args[1] == symbol( "@sprintf" ) ||
        isexpr( ex, :call ) && in( ex.args[1], [:replace, :string, :utf8, :utf16, :utf32, :repr, :normalize_string, :join, :chop, :chomp,
            :lpad, :rpad, :strip, :lstrip, :rstrip, :uppercase, :lowercase, :ucfirst, :lcfirst,
            :escape_string, :unescape_string ] )
        return String
    end

    if isexpr( ex, :(:) )
        return Range
    end

    if isexpr( ex, :call ) && isexpr( ex.args[1], :curly )
        ret=Any
        try
            ret = eval( ex.args[1] )
        end
        return ret
    end

    if isexpr( ex, :call ) && ex.args[1] == :Array
        ret = Array
        try
            ret = Array{ eval( ex.args[2] ), length(ex.args)-2 }
        end
        return ret
    end

    if isexpr( ex, :ref ) # it could be a ref a[b] or an array Int[1,2,3]
        if typeof( ex.args[1] ) == Symbol && isupper( string( ex.args[1] )[1] ) # assume an array
            elt = Any
            try
                elt = eval( ex.args[1] )
            end
            if typeof( elt ) == DataType
                return Array{ elt, 1 }
            end
        end
    end

    if isexpr( ex, :typed_dict ) && isexpr( ex.args[1], :(=>) ) &&
        typeof( ex.args[1].args[1] ) == Symbol && typeof( ex.args[1].args[2] ) == Symbol
        ret = Dict
        try
            ret = Dict{ eval( ex.args[1].args[1] ), eval( ex.args[1].args[2] ) }
        end
        return ret
    end
    if isexpr( ex, :dict )
        return Dict
    end
    if isexpr( ex, :comparison )
        return Bool
    end


    # simple if statement e.g. test ? 0 : 1
    if isexpr( ex, :if ) && length( ex.args ) == 3
        tt = guesstype( ex.args[2], ctx )
        ft = guesstype( ex.args[3], ctx )
        if tt == ft
            return tt
        else
            return Any
        end
    end

    if isexpr( ex, :(->))
        return Function
    end

    return Any
end

function lintassignment( ex::Expr, ctx::LintContext; islocal = false, isConst=false, isGlobal=false, isForLoop=false ) # is it a local decl & assignment?
    lintexpr( ex.args[2], ctx )

    syms = Symbol[]
    typeassert = Dict{ Symbol, Any }()
    resolveLHSsymbol( ex.args[1], syms, ctx, typeassert )
    RHStype = guesstype( ex.args[2], ctx )

    if isForLoop
        if length(syms)==1 && RHStype <: Dict
            msg( ctx, 0, "Typically iteration over dictionary uses a (k,v) tuple. Here only one variable is used." )
        end
        if RHStype <: Number
            msg( ctx, 0, "Iteration works for a number but it may be a typo." )
        end
    end

    for s in syms
        vi = VarInfo( ctx.line )
        try
            if haskey( typeassert, s )
                dt = eval( typeassert[ s ] )
                if typeof( dt ) == DataType
                    vi.typeactual = dt
                    if dt !=Any && RHStype != Any && !( RHStype <: dt )
                        msg( ctx, 0, "Assert " * string(s) * " type= " * string( dt ) * " but assign a value of " * string( RHStype ) )
                    end
                else
                    vi.typeexpr = typeassert[ s ]
                end
            elseif RHStype != Any
                vi.typeactual = RHStype
            end
        catch
            vi.typeexpr = typeassert[s]
        end

        if in( s, [ :e, :pi, :eu, :catalan, :eulergamma, :golden, :π, :γ, :φ ] )
            if ctx.file != "constants.jl"
                msg( ctx, 1, "You are redefining a mathematical constant " * string(s) )
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
                    if vi.typeactual != Any && !( vi.typeactual <: prevvi.typeactual )
                        msg( ctx, 1, "Previously used " * string( s ) * " has apparent type " * string( prevvi.typeactual ) * ", but now assigned " * string( vi.typeactual ) )
                    end
                    ctx.callstack[end].localvars[i][ s] = vi
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
                ctx.callstack[end].localvars[1][ s ] = vi
            end
        end
        if isGlobal || isConst || (ctx.functionLvl + ctx.macroLvl == 0 && ctx.callstack[end].isTop)
            ctx.callstack[end].declglobs[ s ] = { :file => ctx.file, :line => ctx.line }
        end
    end
end

