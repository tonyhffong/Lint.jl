commoncollections = DataType[ Array, AbstractArray, BitArray, Set, Associative ]
commoncollmethods = Dict{ Symbol, Set{ DataType }} ()

function initcommoncollfuncs()
    global commoncollmethods, commoncollections
    for t in commoncollections
        ms = methodswith( t )
        for m in ms
            str = string(m)
            mtch = match( r"^[a-zA-Z_][a-zA-Z0-9_]*(!)?", str )
            if mtch != nothing
                if in( mtch.match, [ "hash", "show", "rand",
                    "isequal", "convert", "serialize", "isless",
                    "writemime", "write", "Dict" ] )
                    continue
                end
                s = symbol( mtch.match )
                if !haskey( commoncollmethods, s )
                    commoncollmethods[s] = Set{ DataType }()
                end
                push!( commoncollmethods[s], t )
            end
        end
    end
    for (k,v) in  commoncollmethods
        if length( v ) < 2
            delete!( commoncollmethods, k )
        end
    end
    # ADD COMMON FUNCTIONS WITH EASILY-MISTAKEN SIGNATURES HERE
    commoncollmethods[ :(append!) ] = Set{DataType}()
end

function lintfuncargtype( ex, ctx::LintContext )
    if typeof( ex ) <: Expr && ex.head == :curly
        st = 2
        en = 1
        if ex.args[1] == :Array
            en = 2
        elseif ex.args[1] == :Dict
            en = 3
        end
        for i in st:en
            if in( ex.args[i], [ :Number ] )
                msg( ctx, 2, "Type parameters in Julia are invariant, meaning " *
                    string(ex) * " may not do what you want. Try f{T<:Number}(x::T)... " )
            end
        end
    end
end

# if ctorType isn't symbol( "" ) then we are in the context of
# a constructor for a type. We would check
# * if the function name matches the type name
function lintfunction( ex::Expr, ctx::LintContext; ctorType = symbol( "" ), isstaged=false )
    if ex.args[1].args[1]==:eval # extending eval(m,x) = ... in module. don't touch it.
        return
    end

    temporaryTypes = Any[]
    fname = symbol("")
    if ex.args[1].head == :tuple # anonymous
        # do nothing
    elseif isexpr( ex.args[1].args[1], :(.) )
        fname = ex.args[1].args[1]
        push!( ctx.callstack[end].functions, fname.args[end] )
    elseif typeof(ex.args[1].args[1]) == Symbol
        fname = ex.args[1].args[1]
        push!( ctx.callstack[end].functions, fname )
    elseif ex.args[1].args[1].head == :curly
        fname = ex.args[1].args[1].args[1]
        push!( ctx.callstack[end].functions, fname )
        for i in 2:length( ex.args[1].args[1].args)
            adt = ex.args[1].args[1].args[i]
            if typeof(adt) == Symbol
                if in(adt, knowntypes )
                    msg( ctx, 2, "You mean {T<:"*string( adt )*"}? You are introducing it as a new name for an implicit argument to the function, unrelated to the type " * string(adt))
                else
                    push!( temporaryTypes, adt )
                end
            elseif isexpr( adt, :(<:) )
                temptype = adt.args[1]
                typeconstraint = adt.args[2]
                if in( temptype, knowntypes )
                    msg( ctx, 2, "You should use {T<:...} instead of a known type " * string(temptype))
                end
                if in( typeconstraint, knowntypes )
                    dt = eval( typeconstraint )
                    if typeof( dt ) == DataType && isleaftype( dt )
                        msg( ctx, 2, string( dt )* " is a leaf type. As a type constraint it makes no sense in " * string(adt) )
                    end
                end
                push!( temporaryTypes, adt.args[1] )
            end
        end
    elseif ex.args[1].args[1].head == :($)
        lintexpr( ex.args[1].args[1].args[1], ctx )
    end
    ctx.scope = string(fname)
    if fname != symbol( "" ) && !contains( ctx.file, "deprecate" )
        isDeprecated = functionIsDeprecated( ex.args[1] )
        if isDeprecated != nothing && !pragmaexists( "Ignore deprecated " * string( fname ), ctx )
            msg( ctx, 2, isDeprecated.message * "\nSee: deprecated.jl " * string( isDeprecated.line ) )
        end
    end

    if ctx.macroLvl == 0 && ctx.functionLvl == 0
        pushcallstack( ctx )
    else
        push!( ctx.callstack[end].localarguments, Dict{ Symbol,Any }() )
        push!( ctx.callstack[end].localusedargs, Set{ Symbol }() )
    end
    ctx.functionLvl = ctx.functionLvl + 1
    # grab the arguments. push a new stack, populate the new stack's argument fields and process the block
    stacktop = ctx.callstack[end]
    # temporaryTypes are the type parameters in curly brackets, make them legal in the current scope
    union!( stacktop.types, temporaryTypes )

    argsSeen = Set{ Symbol }()
    optionalposition = 0
    typeRHShints = Dict{ Symbol, Any }() # x = 1
    typeassert = Dict{Symbol, Any}() # e.g. x::Int

    resolveArguments = (sube, position) -> begin # zero position means it's not called at the top level
        if typeof( sube ) == Symbol
            if in( sube, argsSeen )
                msg( ctx, 2, "Duplicate argument: " * string( sube) )
            end
            if position != 0 && optionalposition != 0
                msg( ctx, 2, "You cannot have non-default argument following default arguments")
            end
            if isupper( string(sube)[1] )
                msg( ctx, 0, "Julia style recommends arguments start in lower case: " * string(sube) )
            end
            push!( argsSeen, sube )
            if isstaged
                typeassert[ sube ] = DataType
            end
            return sube
        elseif sube.head == :parameters
            for (j,kw) in enumerate(sube.args)
                if typeof(kw)==Expr && kw.head == :(...)
                    if j != length(sube.args)
                        msg( ctx, 2, "Named ellipsis ... can only be the last argument")
                        return
                    end
                    sym = resolveArguments( kw, 0 )
                    if typeof( sym )== Symbol
                        if isstaged
                            typeassert[ sym ] = DataType
                        else
                            # This may change to Array{ (Symbol,Any ), 1 } in the future
                            typeassert[ sym ] = Array{Any,1}
                        end
                    end
                    return
                elseif typeof( kw ) != Expr || (kw.head != :(=) && kw.head != :kw)
                    msg( ctx, 2, "Named keyword argument must have a default: " *string(kw))
                    return
                else
                    resolveArguments( kw, 0 )
                end
            end
        elseif sube.head == :(=) || sube.head == :kw
            if position != 0
                optionalposition = position
            end
            sym = resolveArguments( sube.args[1], 0 )
            if !isstaged
                rhstype = guesstype( sube.args[2], ctx )
                if typeof( sym ) == Symbol
                    typeRHShints[ sym ] = rhstype
                end
            end
        elseif sube.head == :(::)
            if length( sube.args ) > 1
                sym = resolveArguments( sube.args[1], 0 )
                if !isstaged
                    if typeof( sym ) == Symbol
                        dt = parsetype( sube.args[2] )
                        typeassert[ sym ] = dt
                    end
                end
                lintfuncargtype( sube.args[2], ctx )
                return sym
            else
                lintfuncargtype( sube.args[1], ctx )
            end
        elseif sube.head == :(...)
            if position != 0 && position != length(ex.args[1].args)
                msg( ctx, 2, "Positional ellipsis ... can only be the last argument")
            end
            sym = resolveArguments( sube.args[1], 0 )
            if typeof(sym) == Symbol
                if isstaged
                    typeassert[ sym ] = (DataType...,)
                elseif haskey( typeassert, sym )
                    typeassert[ sym ] = (typeassert[sym]...,)
                else
                    typeassert[ sym ] = (Any...,)
                end
            end
        elseif sube.head == :($)
            lintexpr( sube.args[1], ctx )
        else
            msg( ctx, 2, "Lint does not understand: " *string( sube ) * " as an argument " * string( position ) )
        end
        return nothing
    end

    for i = (fname == symbol("") ? 1 : 2 ):length(ex.args[1].args)
        resolveArguments( ex.args[1].args[i], i )
    end

    for s in argsSeen
        vi = VarInfo( ctx.line )
        try
            if haskey( typeassert, s )
                dt = eval( typeassert[ s ] )
                if typeof(dt ) == DataType || typeof(dt ) == (DataType,)
                    vi.typeactual = dt
                    if dt != Any && haskey( typeRHShints, s ) && typeRHShints[s] != Any &&
                        !( typeRHShints[s] <: dt )
                        msg( ctx, 2, string( s ) * " type assertion and default seem inconsistent" )
                    end
                end
            elseif haskey( typeRHShints, s )
                vi.typeactual = typeRHShints[s]
            end
        end
        stacktop.localarguments[end][s] = vi
    end

    prev_isstaged = ctx.isstaged
    ctx.isstaged = isstaged
    pushVarScope( ctx )
    lintexpr( ex.args[2], ctx )

    if ctorType != symbol( "" ) && fname != ctorType && in( :new, ctx.callstack[end].calledfuncs )
        msg( ctx, 2, "Constructor-like function " * string( fname ) * " within type " * string( ctorType ) * ". Shouldn't they match?" )
    end
    if ctorType != symbol( "" ) && fname == ctorType
        t = guesstype( ex.args[2], ctx )
        if typeof( t ) == DataType
            if t.name.name != ctorType
                msg( ctx, 2, "Constructor doesn't seem to return the constructed object. " )
            end
        elseif t != ctorType
            msg( ctx, 2, "Constructor doesn't seem to return the constructed object. " )
        end
    end
    popVarScope( ctx, checkargs=true )

    ctx.functionLvl = ctx.functionLvl - 1
    # TODO check cyclomatic complexity?
    if ctx.macroLvl == 0 && ctx.functionLvl == 0
        popcallstack( ctx )
    else
        pop!( ctx.callstack[end].localarguments )
        pop!( ctx.callstack[end].localusedargs )
    end
    ctx.scope = ""
    ctx.isstaged = prev_isstaged
end

function lintlambda( ex::Expr, ctx::LintContext )
    stacktop = ctx.callstack[end]
    push!( stacktop.localarguments, Dict{Symbol, Any}() )
    push!( stacktop.localusedargs, Set{Symbol}() )
    pushVarScope( ctx )
    # check for conflicts on lambda arguments
    checklambdaarg = (sym)->begin
        for i in length(stacktop.localvars):-1:1
            if haskey( stacktop.localvars[i], sym )
                msg( ctx, 1, "Lambda argument " * string( sym ) * " conflicts with a local variable. Best to rename.")
                break
            end
        end
        for i in length(stacktop.localarguments):-1:1
            if haskey( stacktop.localarguments[i], sym )
                msg( ctx, 1, "Lambda argument " * string( sym ) * " conflicts with an argument. Best to rename.")
                break
            end
        end
        for i in length( ctx.callstack ):-1:1
            if haskey( ctx.callstack[i].declglobs, sym )
                msg( ctx, 1, "Lambda argument " * string( sym ) * " conflicts with an declared global from \n" * string(ctx.callstack[i].declglobs[ sym ])*  "\nBetter to rename.")
            end
        end
        stacktop.localarguments[end][sym] = VarInfo( ctx.line )
    end

    resolveArguments = (sube) -> begin
        if typeof( sube ) == Symbol
            checklambdaarg( sube )
            stacktop.localarguments[end][sube]=VarInfo(ctx.line)
        #= # until lambda supports named args, keep this commented
        elseif sube.head == :parameters
            for kw in sube.args
                resolveArguments( kw )
            end
        =#
        elseif isexpr( sube, Symbol[ :(=), :(kw), :(::), :(...) ] )
            if sube.head == :(=) || sube.head == :kw
                resolveArguments( sube.args[1] )
            elseif sube.head == :(::)
                if length( sube.args ) > 1
                    resolveArguments( sube.args[1] )
                end
            elseif sube.head == :(...)
                resolveArguments( sube.args[1])
            end
        else
            msg( ctx, 2, "Lint does not understand: " *string( sube ) * " as an argument.")
        end
    end

    if typeof( ex.args[1] ) == Symbol
        resolveArguments( ex.args[1] )
    elseif isexpr( ex.args[1], :tuple )
        for i = 1:length(ex.args[1].args)
            resolveArguments( ex.args[1].args[i] )
        end
    else
        resolveArguments( ex.args[1] )
    end
    lintexpr( ex.args[2], ctx )

    popVarScope( ctx, checkargs=true )
    pop!( stacktop.localarguments )
    pop!( stacktop.localusedargs )
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

        inclfile = joinpath( ctx.path, inclfile )

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
            ctx.lineabs = 1
            lintstr( str, ctx )
            ctx.file = file
            ctx.path = path
            ctx.lineabs = lineabs
        end
    else
        if isexpr( ex.args[1], :curly )
            lintcurly( ex.args[1], ctx )
        end

        if ex.args[1]== :Dict || isexpr( ex.args[1], :curly ) && ex.args[1].args[1] == :Dict
            lintdict4( ex, ctx )
            return
        end
        known=false

        # deprecation of specialized version of constructors
        deprector = Any[
        ( :symbol  , :Symbol ) ,
        ( :uint    , :UInt)    ,
        ( :uint8   , :UInt8)   ,
        ( :uint16  , :UInt16)  ,
        ( :uint32  , :UInt32)  ,
        ( :uint64  , :UInt64)  ,
        ( :uint128 , :UInt128) ,
        ( :float16 , :Float16) ,
        ( :float32 , :Float32) ,
        ( :float64 , :Float64) ,
        ( :int     , :Int)     ,
        ( :int8    , :Int8)    ,
        ( :int16   , :Int16)   ,
        ( :int32   , :Int32)   ,
        ( :int64   , :Int64)   ,
        ( :int128  , :Int128)
        ]
        versionreachable = ctx.versionreachable( VERSION )
        for row in deprector
            if VERSION < v"0.4.0-dev+1830" && versionreachable && ex.args[1] == row[2]
                msg( ctx, 2, "Though valid in 0.4, you want " * string( row[1] ) * "() instead of " * string( row[2] ) * "()" )
            end
            if VERSION >= v"0.4.0-dev+1830" && versionreachable && ex.args[1] == row[1]
                msg( ctx, 0, "In 0.4+, replace " * string( row[1] ) * "() with " * string( row[2] ) * "()" )
            end
        end
        if ex.args[1] == :String
            msg( ctx, 2, "You want string(), i.e. string conversion, instead of a non-existent constructor" )
        elseif ex.args[1]==:(+)
            lintplus( ex, ctx )
            known = true
        end

        skiplist = Int[]
        global commoncollmethods

        if typeof( ex.args[1] ) == Symbol && haskey( commoncollmethods, ex.args[1] )
            known=true
            s = ex.args[1]
            typesig = Any[]
            for i in 2:length( ex.args )
                if !isexpr( ex.args[i], :kw ) && !isexpr( ex.args[i], :parameters )
                    push!( typesig, guesstype( ex.args[i], ctx ) )
                end
            end
            try
                which( getfield( Base, s ),  tuple( typesig... ) )
            catch er
                msg( ctx, 2, string(s) * ": " * string( er ) * "\nSignature: " * string( typesig ) )
            end
        end

        #splice! allows empty range such as 3:2, it means inserting an array
        # between position 2 and 3, without taking out any value.
        if ex.args[1] == symbol( "splice!" ) && Meta.isexpr( ex.args[3], :(:) ) &&
            length( ex.args[3].args ) == 2 && typeof( ex.args[3].args[1] ) <: Real &&
            typeof( ex.args[3].args[2] ) <: Real && ex.args[3].args[2] < ex.args[3].args[1]
            push!( skiplist, 3 )
        end

        if ex.args[1] == :new
            tname = symbol( ctx.scope )
            for i = length( ctx.callstack ):-1:1
                if haskey( ctx.callstack[i].typefields, tname )
                    fields = ctx.callstack[i].typefields[ tname ]
                    if 0 < length( ex.args ) - 1 < length( fields )
                        if !pragmaexists( "Ignore short new argument", ctx, deep=false )
                            msg( ctx, 0, "new is provided with fewer arguments than fields." )
                        end
                    elseif length( fields ) < length( ex.args ) - 1
                        msg( ctx, 2, "new is provided with more arguments than fields" )
                    end
                    break
                end
            end
            known=true
        end

        st = 2
        if ex.args[1] == :ifelse && typeof( ex.args[2] ) == Expr
            lintboolean( ex.args[2], ctx )
            st = 3
            known=true
        end

        if !known && isa( ex.args[1], Symbol )
            registersymboluse( ex.args[1], ctx, false )
        end

        en = length(ex.args)

        if isexpr( ex.args[1], :curly )
            # Dict{Symbol, Int}
            lintexpr( ex.args[1], ctx )
        elseif isexpr( ex.args[1], :(.))
            lintexpr( ex.args[1], ctx )
        elseif typeof( ex.args[1] ) == Symbol
            push!( ctx.callstack[end].calledfuncs, ex.args[1] )
        end

        for i in st:en
            if in( i, skiplist )
                continue
            elseif isexpr( ex.args[i ], :parameters )
                for kw in ex.args[i].args
                    if isexpr( kw, :(...) )
                        lintexpr( kw.args[1], ctx )
                    elseif length(kw.args) != 2
                        msg( ctx, 2, "unknown keyword pattern " * string(kw))
                    else
                        lintexpr( kw.args[2], ctx )
                    end
                end
            elseif isexpr( ex.args[i], :kw )
                lintexpr( ex.args[i].args[2], ctx )
            else
                lintexpr( ex.args[i], ctx )
            end
        end
    end
end

function lintplus( ex::Expr, ctx::LintContext )
    for i in 2:length(ex.args)
        if guesstype( ex.args[i], ctx ) <: String
            msg( ctx, 2, "String uses * to concatenate.")
            break
        end
    end
end
