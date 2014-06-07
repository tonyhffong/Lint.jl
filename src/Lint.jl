# Julia's homoiconicity is crying out for an awesome lint module

module Lint
export LintMessage
export lintfile, lintstr, lintpragma
export test_similarity_string

const SIMILARITY_THRESHOLD = 10.0

# Wishlist:
# setting a value to a datatype instead of an instance of that type
# repeated pattern in Dict =>, like :a => a, :b => b, etc. Suggest macro.
# warn push! vs append! (requires understanding of types)
# warn eval
# warn variable name used outside scope, even if it's ok

include( "types.jl" )
include( "knownsyms.jl")

# no-op, the presence of this can suppress lint messages locally
function lintpragma( s::String )
end

function lintfile( file::String )
    if !ispath( file )
        throw( "no such file exists")
    end

    ctx = LintContext()
    ctx.file = file
    str = open(readall, file)
    msgs = lintstr( str, ctx )
    for m in msgs
        println( m )
    end
end

function lintstr( str::String, ctx :: LintContext = LintContext() )
    linecharc = cumsum( map( x->length(x)+1, split( str, "\n", true ) ) )
    i = start(str)
    while !done(str,i)
        problem = false
        ex = nothing
        ctx.lineabs = searchsorted( linecharc, i ).start
        try
            (ex, i) = parse(str,i)
        catch
            #println( y )
            problem = true
        end
        if !problem
            lintexpr( ex, ctx )
        else
            break
        end
    end
    return ctx.messages
end

function msg( ctx, lvl, str )
    push!( ctx.messages, LintMessage( ctx.file , ctx.scope,
            ctx.lineabs + ctx.line-1, lvl, str ) )
end

function lintexpr( ex, ctx::LintContext )
    if typeof(ex) == Symbol
        registersymboluse( ex, ctx )
        return
    end
    if typeof(ex)!=Expr
        return
    end

    if ex.head == :block
        lintblock( ex, ctx )
    elseif ex.head == :if
        lintifexpr( ex, ctx )
    elseif ex.head == :(=)
        if typeof(ex.args[1])==Expr && ex.args[1].head == :call
            lintfunction( ex, ctx )
        else
            lintassignment( ex, ctx )
        end
    elseif ex.head == :local
        lintlocal( ex, ctx )
    elseif ex.head == :global
        lintglobal( ex, ctx )
    elseif ex.head == :const
        if typeof( ex.args[1] ) == Expr && ex.args[1].head == :(=)
            lintassignment( ex.args[1], ctx; isConst = true )
        else
            lintexpr( ex.args[1], ctx )
        end
    elseif ex.head == :module
        lintmodule( ex, ctx )
    elseif ex.head == :using
        lintusing( ex, ctx )
    elseif ex.head == :export
        lintexport( ex, ctx )
    elseif ex.head == :import # single name import. e.g. import Base
        lintimport( ex, ctx )
    elseif ex.head == :importall
        lintimport( ex, ctx; all=true )
    elseif ex.head == :toplevel # import Base: foo, bar, ..., or import Core,Base
        linttoplevel( ex, ctx )
    elseif ex.head == :comparison # only the odd indices
        for i in 1:2:length(ex.args)
            a = ex.args[i]
            if typeof(a)==Symbol
                registersymboluse( a, ctx )
            elseif typeof(a)==Expr
                lintexpr( a, ctx )
            end
        end
    elseif ex.head == :type
        linttype( ex, ctx )
    elseif ex.head == :typealias
        linttypealias( ex, ctx )
    elseif ex.head == :abstract
        lintabstract( ex, ctx )
    elseif ex.head == :(->)
        lintlambda( ex, ctx )
    elseif ex.head == :function
        lintfunction( ex, ctx )
    elseif ex.head == :macro
        lintmacro( ex, ctx )
    elseif ex.head == :macrocall
        lintmacrocall( ex, ctx )
    elseif ex.head == :call
        lintfunctioncall( ex, ctx )
    elseif ex.head == :(::) # type assert/convert
        lintexpr( ex.args[1], ctx )
    elseif ex.head == :(.) # a.b
        sub1 = ex.args[1]
        if typeof(sub1) == Symbol
            registersymboluse( sub1, ctx )
        else
            lintexpr( sub1, ctx )
        end
    elseif ex.head == :ref # it could be a ref a[b], or an array Int[1,2]
        sub1 = ex.args[1]
        if typeof(sub1)== Symbol
            # check to see if it's a type
            str = string( sub1)
            if !isupper( str[1] )
                registersymboluse( sub1,ctx )
            end
        else
            lintexpr(sub1, ctx)
        end
        for i=2:length(ex.args)
            lintexpr( ex.args[i], ctx )
        end
    elseif ex.head == :dict # homogeneous dictionary
        lintdict( ex, ctx; typed=false )
    elseif ex.head == :typed_dict # mixed type dictionary
        lintdict( ex, ctx; typed=true )
    elseif ex.head == :for
        lintfor( ex, ctx )
    elseif ex.head == :comprehension
        lintcomprehension( ex, ctx; typed = false )
    elseif ex.head == :typed_comprehension
        lintcomprehension( ex, ctx; typed = true )
    elseif ex.head == :try
        linttry( ex, ctx )
    elseif ex.head == :curly # e.g. Ptr{T}
        return
    else
        for sube in ex.args
            if typeof(sube)== Expr
                lintexpr(sube, ctx )
            elseif typeof(sube)==Symbol
                registersymboluse( sube, ctx )
            end
        end
    end
end

function lintblock( ex::Expr, ctx::LintContext )
    global SIMILARITY_THRESHOLD
    if ctx.macrocallLvl == 0
        push!( ctx.callstack[ end ].localvars, Dict{Symbol, Any}() )
        push!( ctx.callstack[ end ].localusedvars, Set{Symbol}() )
    end
    lastexpr = nothing
    similarexprs = Expr[]
    diffs = Float64[]

    checksimilarity = ()->begin
        if length( similarexprs ) <= 2 # not much I can do
            diffs = Float64[]
            lastexpr = nothing
            similarexprs = Expr[]
        else
            # cyclic diffs, so now we have at least 3 similarity scores
            push!( diffs, expr_similar_score( similarexprs[1], similarexprs[end] ) )
            local n = length(diffs)
            local m = mean(diffs)
            local s = std( diffs )
            local m2 = mean( [diffs[end-1], diffs[end] ] )
            # look for screw up at the end
            #println( diffs, "\nm=", m, " s=", s, " m2=", m2, " m-m2=", m-m2)
            if m2 < m && m-m2 > s/2.5
                msg( ctx, 1, "The last of a " *
                    string(n) * "-expr block looks different. " *
                    "\n   Avg similarity score: " * @sprintf( "%.2f", m ) *
                    "  Last part:            " * @sprintf( "%.2f", m2 ) )
            end
            diffs = Float64[]
            lastexpr = nothing
            similarexprs = Expr[]
        end
    end

    for (i,sube) in enumerate(ex.args)
        if typeof(sube) == Expr
            if sube.head == :line
                ctx.line = sube.args[1]
                if length(sube.args)>1
                    file= string(sube.args[2])
                    if file != "none"
                        ctx.file = file
                    end
                end
                continue
            elseif sube.head == :return && i != length(ex.args)
                msg( ctx, 1, "Unreachable code after return" )
                lintexpr( sube, ctx )
                break
            else
                if lastexpr != nothing
                    local dif = expr_similar_score( lastexpr, sube )
                    if dif > SIMILARITY_THRESHOLD
                        if !isempty(similarexprs)
                            append!( similarexprs, [lastexpr, sube ] )
                        else
                            push!( similarexprs, sube )
                        end
                        push!( diffs, dif )
                    else
                        checksimilarity()
                    end
                end
                lintexpr( sube, ctx )
                lastexpr = sube
            end
        elseif typeof(sube) == LineNumberNode
            ctx.line = sube.line
            continue
        elseif typeof(sube) == Symbol
            registersymboluse( sube, ctx )
            checksimilarity()
        end
    end

    checksimilarity()

    if ctx.macrocallLvl==0
        unused = setdiff( keys(ctx.callstack[end].localvars[end]), ctx.callstack[end].localusedvars[end] )
        for v in unused
            ctx.line = ctx.callstack[end].localvars[end][ v ]
            msg( ctx, 1, "Local vars declared but not used: " * string( v ) )
        end

        pop!( ctx.callstack[end].localvars )
        pop!( ctx.callstack[end].localusedvars )
    end
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

    found = false
    for i in length(stacktop.localvars):-1:1
        if haskey( stacktop.localvars[i], sym )
            push!( stacktop.localusedvars[i], sym )
            found = true
            break
        end
    end
    if !found
        found = haskey( stacktop.arguments, sym )
        if found
            push!( stacktop.usedvars, sym )
        end
    end

    if !found
        for i in length(ctx.callstack):-1:1
            found = in( sym, ctx.callstack[i].declglobs ) ||
                in( sym, ctx.callstack[i].functions ) ||
                in( sym, ctx.callstack[i].types ) ||
                in( sym, ctx.callstack[i].modules ) ||
                in(sym, stacktop.imports )
            if found
                break
            end
        end
    end

    # a bunch of whitelist
    if in( sym, knownsyms )
        return
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
            push!( ctx.callstack[end].declglobs, sym )
        end
    end

    if !found
        msg( ctx, 2, "Use of undeclared symbol " *string(sym))
    end
end

function expr_similar_score( e1::Expr, e2::Expr, base::Float64 = 1.0 )
    if e1.head != e2.head
        return -base
    end

    score = base - abs( length(e1.args)-length(e2.args)) * base * 2.0

    for i in 1:min( length(e1.args), length(e2.args) )
        if typeof(e1.args[i]) == Expr && typeof(e2.args[i]) == Expr
            score += expr_similar_score( e1.args[i], e2.args[i], base * 1.1 )
        elseif typeof(e1.args[i]) == typeof(e2.args[i])
            score += base * 0.3
            if e1.args[i] == e2.args[i]
                score += base * 0.8
            end
        else
            score -= base
        end
        if score < 0.0 # so early disagreement dominates and short-circuit
            break
        end
    end
    return score
end

function test_similarity_string( str::String )
    i = start(str)
    firstexpr = nothing
    lastexpr = nothing
    diffs = Float64[]
    while !done(str,i)
        problem = false
        ex = nothing
        try
            (ex, i) = parse(str,i)
        catch
            problem = true
        end
        if !problem
            if firstexpr == nothing
                firstexpr = ex
            end
            if lastexpr != nothing
                push!( diffs, expr_similar_score( lastexpr, ex ))
            end
            lastexpr = ex
        else
            break
        end
    end
    if lastexpr != nothing && length(diffs) >= 2
        push!( diffs, expr_similar_score( lastexpr, firstexpr ) )
    end
    return diffs
end

function lintifexpr( ex::Expr, ctx::LintContext )
    if ex.args[1] == false
        msg( ctx, 1, "true branch is unreachable")
        if length(ex.args) > 2
            lintexpr( ex.args[3], ctx )
        end
    elseif ex.args[1] == true
        lintexpr( ex.args[2], ctx )
        if length(ex.args) > 2
            msg( ctx, 1, "false branch is unreachable")
        else
            msg( ctx, 1, "redundant if-true statement")
        end
    else
        if typeof(ex.args[1]) == Expr
            lintboolean( ex.args[1], ctx )
        end
        lintexpr( ex.args[2], ctx )
        if length(ex.args) > 2
            lintexpr( ex.args[3], ctx )
        end
    end
end

function lintboolean( ex::Expr, ctx::LintContext )
    if ex.head == :(=)
        msg( ctx, 0, "Assignment in the if-predicate clause.")
    elseif ex.head == :call && ex.args[1] in [ :(&), :(|), :($) ]
        msg( ctx, 2, "Bit-wise " * string( ex.args[1]) * " in a boolean context?" )
    elseif ex.head == :(&&) || ex.head == :(||)
        for a in ex.args
            if typeof(a) == Symbol
                registersymboluse(a, ctx)
            elseif typeof(a)== Expr
                lintboolean( a, ctx )
            else
                msg( ctx, 2, "Lint doesn't understand " * string( a ) * " in a boolean context." )
            end
        end
    elseif ex.head ==:call && ex.args[1] == :(!)
        for i in 2:length(ex.args)
            a = ex.args[i]
            if typeof(a) == Symbol
                registersymboluse(a, ctx)
            elseif typeof(a)== Expr
                lintboolean( a, ctx )
            else
                msg( ctx, 2, "Lint doesn't understand " * string( a ) * " in a boolean context." )
            end
        end
    elseif ex.head == :call && ex.args[1] == :length
        msg( ctx, 2, "Incorrect usage of length() in a Boolean context. You want to use isempty().")
    end
    lintexpr( ex, ctx )
end

function lintassignment( ex::Expr, ctx::LintContext; islocal = false, isConst=false, isGlobal=false ) # is it a local decl & assignment?
    lintexpr( ex.args[2], ctx )
    syms = Symbol[]
    if typeof( ex.args[1] ) == Symbol
        syms = [ ex.args[1] ]
    elseif ex.args[1].head == :(::) && typeof( ex.args[1].args[1] ) == Symbol
        syms = [ ex.args[1].args[1] ]
    elseif ex.args[1].head == :tuple
        for s in ex.args[1].args
            if typeof( s ) == Symbol
                push!(syms, s )
            elseif typeof(s)==Expr && s.head == :(::) && typeof( s.args[1] ) == Symbol
                push!(syms, s.args[1])
            else
                lintexpr( s, ctx ) # it could be (a[idx], b[idx]) = ....
            end
        end
    elseif ex.args[1].head == :(.) || ex.args[1].head == :ref # a.b = something or a[b] = something
        lintexpr( ex.args[1], ctx )
        return
    else
        msg( ctx, 2, "LHS in assignment not understood by lint. please check")
    end
    for s in syms
        n = length(ctx.callstack[end].localvars)
        if islocal
            ctx.callstack[end].localvars[n][ s ] = ctx.line
        else
            ctx.callstack[end].localvars[1][ s ] = ctx.line
        end
        if isGlobal || isConst || length( ctx.callstack[end].localvars) == 1 && ctx.callstack[end].isTop
            push!( ctx.callstack[end].declglobs, s )
        end
    end
end

function lintglobal( ex::Expr, ctx::LintContext )
    for sym in ex.args
        if typeof(sym) == Symbol
            push!( ctx.callstack[end].declglobs, sym )
        elseif typeof(sym) == Expr && sym.head == :(=)
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

function lintmodule( ex::Expr, ctx::LintContext )
    file = ctx.file
    line = ctx.line
    push!( ctx.callstack[end].modules, ex.args[2] )
    push!( ctx.callstack, LintStack() )
    topstack = ctx.callstack[end]
    topstack.inModule = true
    topstack.moduleName = ex.args[2]
    topstack.isTop = true

    lintexpr( ex.args[3], ctx )

    undefs = setdiff( topstack.exports, topstack.types )
    undefs = setdiff( undefs, topstack.functions )
    undefs = setdiff( undefs, topstack.macros )
    undefs = setdiff( undefs, topstack.declglobs )
    undefs = setdiff( undefs, keys( topstack.localvars[1] ) )
    undefs = setdiff( undefs, topstack.imports )

    for sym in undefs
        msg( ctx, 2, "exporting undefined symbol " * string(sym))
    end
    pop!( ctx.callstack )
end

function lintusing( ex::Expr, ctx::LintContext )
    for s in ex.args
        push!( ctx.callstack[end].declglobs, s )
    end
    problem = false
    m = nothing
    try
        path = string( ex.args[1] )
        for i in 2:length(ex.args)
            path = path * "." * string(ex.args[i])
        end
        m = eval( path )
    catch er
        problem = true
        println( er )
        println( ex )
    end
    if !problem
        t = typeof( m )
        if t == Module
            union!( ctx.callstack[end].declglobs, names( m ) )
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

function lintfunction( ex::Expr, ctx::LintContext )
    if ex.args[1].args[1]==:eval # extending eval(m,x) = ... in module. don't touch it.
        return
    end

    temporaryTypes = {}
    fname = symbol("")
    if typeof(ex.args[1].args[1]) == Symbol
        fname = ex.args[1].args[1]
        push!( ctx.callstack[end].functions, fname )
    elseif ex.args[1].args[1].head == :curly
        fname = ex.args[1].args[1].args[1]
        push!( ctx.callstack[end].functions, fname )
        for i in 2:length( ex.args[1].args[1].args)
            adt = ex.args[1].args[1].args[i]
            if typeof(adt) == Symbol
                push!( temporaryTypes, adt )
            elseif typeof(adt)==Expr && adt.head == :(<:)
                push!( temporaryTypes, adt.args[1] )
            end
        end
    end
    ctx.scope = string(fname)
    #println(fname)

    if ctx.macrocallLvl == 0 && ctx.functionLvl == 0
        push!( ctx.callstack, LintStack() )
    end
    ctx.functionLvl = ctx.functionLvl + 1
    # grab the arguments. push a new stack, populate the new stack's argument fields and process the block
    topstack = ctx.callstack[end]
    union!( topstack.types, temporaryTypes )
    #topstack.arguments
    for i = 2:length(ex.args[1].args)
        arg = ex.args[1].args[i]
        if typeof( arg )==Symbol
            argsym = symbol( arg )
            topstack.arguments[ argsym ]= 1
        elseif arg.head == :parameters
            for kw in arg.args
                if typeof(kw.args[1])==Symbol
                    argsym = kw.args[1]
                    topstack.arguments[ argsym ] = 1
                elseif kw.args[1].head == :(::) && length( kw.args[1].args ) > 1 && typeof(kw.args[1].args[1])==Symbol
                    argsym = kw.args[1].args[1]
                    topstack.arguments[ argsym ] = 1
                elseif kw.head == :(...)
                    argsym = kw.args[1]
                    topstack.arguments[ argsym ] = 1
                else
                    msg( ctx, 2, "Lint does not understand: " *string( kw ))
                    continue
                end
            end
        elseif arg.head == :(=) || arg.head == :kw
            lhs = arg.args[1]
            if typeof(lhs) == Symbol
                argsym = lhs
                topstack.arguments[ argsym ] = 1
            elseif typeof(lhs) == Expr && lhs.head == :(::) && typeof( lhs.args[1] ) == Symbol
                argsym = lhs.args[1]
                topstack.arguments[ argsym ] = 1
            else
                msg( ctx, 2, "Lint does not understand: " *string( lhs ))
                continue
            end
        elseif arg.head == :(::) && length( arg.args ) > 1
            argsym = arg.args[1]
            topstack.arguments[ argsym ] = 1
        elseif arg.head == :(...)
            if typeof( arg.args[1]) == Symbol
                argsym =  arg.args[1]
                topstack.arguments[ argsym ] = 1
            elseif typeof(arg.args[1])==Expr && arg.args[1].head == :(::)
                argsym = arg.args[1].args[1]
                topstack.arguments[ argsym ] = 1
            else
                msg( ctx, 2, "Lint does not understand: " *string( arg ))
            end
        end
    end

    lintexpr( ex.args[2], ctx )

    ctx.functionLvl = ctx.functionLvl - 1
    # TODO check cyclomatic complexity?
    if ctx.macrocallLvl == 0 && ctx.functionLvl == 0
        pop!( ctx.callstack )
    end
    ctx.scope = ""
end

function lintmacro( ex::Expr, ctx::LintContext )
    if ex.args[1].args[1]==:eval # extending eval(m,x) = ... in module. don't touch it.
        return
    end

    fname = ex.args[1].args[1]
    push!( ctx.callstack[end].macros, symbol( "@" * string(fname ) ) )

    # grab the arguments. push a new stack, populate the new stack's argument fields and process the block
    push!( ctx.callstack, LintStack() )
    topstack = ctx.callstack[end]
    #topstack.arguments
    for i = 2:length(ex.args[1].args)
        arg = ex.args[1].args[i]
        if typeof( arg )==Symbol
            argsym = arg
        elseif arg.head == :parameters
            for kw in arg.args
                if typeof(kw.args[1])==Symbol
                    argsym = kw.args[1]
                    topstack.arguments[ argsym ] = 1
                elseif kw.args[1].head == :(::) && typeof(kw.args[1].args[1])==Symbol
                    argsym = kw.args[1].args[1]
                    topstack.arguments[ argsym ] = 1
                else
                    msg( ctx, 2, "Lint does not understand: " *string( kw ))
                    continue
                end
            end
        elseif arg.head == :(=)
            lhs = arg.args[1]
            if typeof(lhs) == Symbol
                argsym = lhs
            elseif typeof(lhs) == Expr && lhs.head == :(::)
                argsym = lhs.args[1]
            else
                msg( ctx, 2, "Lint does not understand: " *string( lhs ))
                continue
            end
        elseif arg.head == :(::)
            argsym = arg.args[1]
        elseif arg.head == :(...)
            argsym = arg.args[1]
        end
        topstack.arguments[ argsym ] = 1
    end

    lintexpr( ex.args[2], ctx )

    # TODO check cyclomatic complexity?
    pop!( ctx.callstack )
end

function lintfunctioncall( ex::Expr, ctx::LintContext )
    if ex.args[1]==:include
        if typeof( ex.args[2] ) <: String
            inclfile = string(ex.args[2])
        else
            inclfile = ""
            try
                inclfile = eval( ex.args[2] )
            catch
                inclfile = string( ex.args[2] )
            end
        end

        if !ispath( inclfile )
            inclfile = ctx.path * "/" * inclfile
        end

        if !ispath( inclfile )
            msg( ctx, 3, "cannot find include file: " * inclfile )
            return
        else
            println( inclfile )
            path = ctx.path
            file = deepcopy( ctx.file )
            lineabs = ctx.lineabs
            str = open(readall, inclfile )
            ctx.file = deepcopy( inclfile )
            ctx.path = dirname( inclfile )
            lintstr( str, ctx )
            ctx.file = file
            ctx.path = path
            ctx.lineabs = lineabs
        end
    else
        st = 2
        en = length(ex.args)
        if ex.args[1] in [ :map, :open ] && typeof( ex.args[2] ) == Symbol
            st = 3
        end

        if ex.args[1] == :finalizer && typeof(ex.args[3]) == Symbol
            en = min(2,en)
        end

        if ex.args[1] == :Array
            st = 3
        end

        if typeof( ex.args[1] )== Expr && ex.args[1].head == :curly
            # Dict{Symbol, Int}()
            # not much to do there
            return
        end

        for i in st:en
            if typeof(ex.args[i]) == Expr && ex.args[i].head == :parameters
                for kw in ex.args[i].args
                    if typeof(kw)==Expr && kw.head == :(...)
                        lintexpr( kw.args[1], ctx )
                    elseif length(kw.args) != 2
                        msg( ctx, 2, "unknown keyword pattern " * string(kw))
                    else
                        lintexpr( kw.args[2], ctx )
                    end
                end
            elseif typeof(ex.args[i])== Expr && ex.args[i].head == :kw
                lintexpr( ex.args[i].args[2], ctx )
            else
                lintexpr( ex.args[i], ctx )
            end
        end
    end
end

function lintmacrocall( ex::Expr, ctx::LintContext )
    if ex.args[1] == symbol("@deprecate")
        return
    end

    ctx.macrocallLvl = ctx.macrocallLvl + 1
    for i = 2:length(ex.args)
        lintexpr( ex.args[i], ctx )
    end
    ctx.macrocallLvl = ctx.macrocallLvl - 1
end

function lintlambda( ex::Expr, ctx::LintContext )
    push!( ctx.callstack[ end ].localvars, Dict{Symbol, Any}() )
    push!( ctx.callstack[ end ].localusedvars, Set{Symbol}() )
    stacktop = ctx.callstack[end]
    # check for conflicts on lambda arguments
    checklambdaarg = (sym)->begin
        for i in length(stacktop.localvars):-1:1
            if haskey( stacktop.localvars[i], sym )
                msg( ctx, 1, "Lambda argument " * string( sym ) * " conflicts with a local variable. Best to rename.")
                return
            end
        end
        if haskey( stacktop.arguments, sym )
            msg( ctx, 1, "Lambda argument " * string( sym ) * " conflicts with an argument. Best to rename.")
            return
        end

        if in( sym, stacktop.declglobs )
            msg( ctx, 1, "Lambda argument " * string( sym ) * " conflicts with an declared global. Best to rename.")
            return
        end

        stacktop.localvars[end][sym] = ctx.line
    end

    if typeof( ex.args[1] ) == Symbol
        checklambdaarg( ex.args[1] )
    else
        for i = 1:length(ex.args[1].args)
            arg = ex.args[1].args[i]
            if typeof( arg )==Symbol
                checklambdaarg( arg )
            elseif arg.head == :parameters
                for kw in arg.args
                    if typeof(kw.args[1])==Symbol
                        checklambdaarg( kw.args[1])
                    elseif kw.args[1].head == :(::) && typeof(kw.args[1].args[1])==Symbol
                        checklambdaarg( kw.args[1].args[1] )
                    else
                        msg( ctx, 2, "Lint does not understand: " *string( kw ))
                        continue
                    end
                end
            elseif arg.head == :(=)
                lhs = arg.args[1]
                if typeof(lhs) == Symbol
                    checklambdaarg( lhs )
                elseif typeof(lhs) == Expr && lhs.head == :(::)
                    checklambdaarg( lhs.args[1] )
                else
                    msg( ctx, 2, "Lint does not understand: " *string( lhs ))
                    continue
                end
            elseif arg.head == :(::)
                checklambdaarg( arg.args[1] )
            elseif arg.head == :(...)
                if typeof( arg.args[1] ) == Symbol
                    checklambdaarg( arg.args[1])
                elseif typeof( arg.args[1] )==Expr && arg.args[1].head == :(::)
                    checklambdaarg( arg.args[1].args[1] )
                else
                    msg( ctx, 2, "Lint does not understand: " * string( arg ))
                end
            end
        end
    end
    lintexpr( ex.args[2], ctx )

    unused = setdiff( keys(stacktop.localvars[end]), stacktop.localusedvars[end] )
    for v in unused
        ctx.line = stacktop.localvars[end][v]
        msg( ctx, 1, "Local vars declared but not used: " * string( v) )
    end
    pop!( stacktop.localvars )
    pop!( stacktop.localusedvars )
end

function linttype( ex::Expr, ctx::LintContext )
    if typeof( ex.args[2] ) == Symbol
        push!( ctx.callstack[end].types, ex.args[2] )
    elseif typeof( ex.args[2] ) == Expr && ex.args[2].head == :curly
        push!( ctx.callstack[end].types, ex.args[2].args[1] )
    elseif typeof( ex.args[2] ) == Expr && ex.args[2].head == :(<:)
        if typeof( ex.args[2].args[1] ) == Symbol
            push!( ctx.callstack[end].types, ex.args[2].args[1] )
        elseif typeof( ex.args[2].args[1] )==Expr && ex.args[2].args[1].head == :curly
            push!( ctx.callstack[end].types, ex.args[2].args[1].args[1] )
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

function lintdict( ex::Expr, ctx::LintContext; typed::Bool = false )
    st = typed ? 2 : 1
    ks = Set{Any}()
    for i in st:length(ex.args)
        a = ex.args[i]
        if typeof(a)== Expr && a.head == :(=>)
            if typeof( a.args[1] ) != Expr
                if in( a.args[1], ks )
                    msg( ctx, 2, "Duplicate key in Dict: " * string( a.args[1] ) )
                end
                push!( ks, a.args[1] )
            end
            lintexpr( a.args[2], ctx )
        end
    end
end

function lintfor( ex::Expr, ctx::LintContext )
    push!( ctx.callstack[ end ].localvars, Dict{Symbol, Any}() )
    push!( ctx.callstack[ end ].localusedvars, Set{Symbol}() )
    stacktop = ctx.callstack[end]

    if typeof(ex.args[1])==Expr && ex.args[1].head == :(=)
        lintassignment( ex.args[1], ctx; islocal=true )
    end
    lintexpr( ex.args[2], ctx )

    pop!( ctx.callstack[ end ].localvars )
    pop!( ctx.callstack[ end ].localusedvars )
end

function lintcomprehension( ex::Expr, ctx::LintContext; typed::Bool = false )
    push!( ctx.callstack[ end ].localvars, Dict{Symbol, Any}() )
    push!( ctx.callstack[ end ].localusedvars, Set{Symbol}() )
    stacktop = ctx.callstack[end]

    st = typed? 3 :2
    fn = typed? 2 :1
    for i in st:length(ex.args)
        if typeof(ex.args[i])==Expr && ex.args[i].head == :(=)
            lintassignment( ex.args[i], ctx; islocal=true )
        end
    end
    lintexpr( ex.args[fn], ctx )

    pop!( ctx.callstack[ end ].localvars )
    pop!( ctx.callstack[ end ].localusedvars )
end

function linttry( ex::Expr, ctx::LintContext )
    push!( ctx.callstack[ end ].localvars, Dict{Symbol, Any}() )
    push!( ctx.callstack[ end ].localusedvars, Set{Symbol}() )
    stacktop = ctx.callstack[end]
    lintexpr( ex.args[1], ctx )
    if typeof(ex.args[2]) == Symbol
        stacktop.localvars[end][ ex.args[2] ] = ctx.line
    end
    for i in 3:length(ex.args)
        lintexpr( ex.args[i], ctx )
    end
    unused = setdiff( keys(stacktop.localvars[end]), stacktop.localusedvars[end] )
    for v in unused
        ctx.line = stacktop.localvars[end][ v]
        msg( ctx, 1, "Local vars declared but not used. " * string( v ) )
    end
    pop!( stacktop.localvars )
    pop!( stacktop.localusedvars )
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
            m = eval( path )
            lastpart = ex.args[end]
        else
            lastpart = ex.args[end]
            m = eval( ex.args[1] )
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
        end
    end
end

end

