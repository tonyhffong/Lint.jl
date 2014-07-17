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
                msg( ctx, 2, "Type parameters in Julia are invariant, meaning although Int <: Number is true, Array{Int,1} <: Array{Number,1} is false. Try f{T<:Number}(x::T)...")
            end
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
    isDeprecated = functionIsDeprecated( ex.args[1] )
    if isDeprecated != nothing
        msg( ctx, 2, isDeprecated.message * "\nSee: deprecated.jl " * string( isDeprecated.line ) )
    end

    if ctx.macroLvl == 0 && ctx.functionLvl == 0
        push!( ctx.callstack, LintStack() )
    else
        push!( ctx.callstack[end].localarguments, Dict{ Symbol, Any }() )
    end
    ctx.functionLvl = ctx.functionLvl + 1
    # grab the arguments. push a new stack, populate the new stack's argument fields and process the block
    stacktop = ctx.callstack[end]
    # temporaryTypes are the type parameters in curly brackets, make them legal in the current scope
    union!( stacktop.types, temporaryTypes )

    argsSeen = Set{ Symbol }()
    optionalposition = 0

    resolveArguments = (sube, position) -> begin # zero position means it's not called at the top level
        if typeof( sube ) == Symbol
            if in( sube, argsSeen )
                msg( ctx, 2, "Duplicate argument: " * string( sube) )
            end
            if position != 0 && optionalposition != 0
                msg( ctx, 2, "You cannot have non-default argument following default arguments")
            end
            stacktop.localarguments[end][sube]=ctx.line
            push!( argsSeen, sube )
        elseif sube.head == :parameters
            for (j,kw) in enumerate(sube.args)
                if typeof(kw)==Expr && kw.head == :(...)
                    if j != length(sube.args)
                        msg( ctx, 2, "Named ellipsis ... can only be the last argument")
                        return
                    end
                elseif typeof( kw ) != Expr || (kw.head != :(=) && kw.head != :kw)
                    msg( ctx, 2, "Named keyword argument must have a default: " *string(kw))
                    return
                end
                resolveArguments( kw, 0 )
            end
        elseif sube.head == :(=) || sube.head == :kw
            if position != 0
                optionalposition = position
            end
            resolveArguments( sube.args[1], 0 )
        elseif sube.head == :(::)
            if length( sube.args ) > 1
                resolveArguments( sube.args[1], 0 )
                lintfuncargtype( sube.args[2], ctx )
            else
                lintfuncargtype( sube.args[1], ctx )
            end
        elseif sube.head == :(...)
            if position != 0 && position != length(ex.args[1].args)
                msg( ctx, 2, "Positional ellipsis ... can only be the last argument")
            end
            resolveArguments( sube.args[1], 0 )
        elseif sube.head == :($)
            lintexpr( sube.args[1], ctx )
        else
            msg( ctx, 2, "Lint does not understand: " *string( sube ))
        end
    end

    for i = 2:length(ex.args[1].args)
        resolveArguments( ex.args[1].args[i], i )
    end

    pushVarScope( ctx )
    lintexpr( ex.args[2], ctx )
    popVarScope( ctx )

    ctx.functionLvl = ctx.functionLvl - 1
    # TODO check cyclomatic complexity?
    if ctx.macroLvl == 0 && ctx.functionLvl == 0
        pop!( ctx.callstack )
    else
        pop!( ctx.callstack[end].localarguments )
    end
    ctx.scope = ""
end

function lintlambda( ex::Expr, ctx::LintContext )
    stacktop = ctx.callstack[end]
    push!( stacktop.localarguments, Dict{Symbol, Any}() )
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
            if haskey( stacktop.localarguments[end], sym )
                msg( ctx, 1, "Lambda argument " * string( sym ) * " conflicts with an argument. Best to rename.")
                break
            end
        end
        if haskey( stacktop.declglobs, sym )
            msg( ctx, 1, "Lambda argument " * string( sym ) * " conflicts with an declared global from \n" * string(stacktop.declglobs[ sym ])*  "\nBetter to rename.")
        end
        stacktop.localarguments[end][sym] = ctx.line
    end

    resolveArguments = (sube) -> begin
        if typeof( sube ) == Symbol
            checklambdaarg( sube )
            stacktop.localarguments[end][sube]=ctx.line
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
        elseif sube.head == :(...)
            resolveArguments( sube.args[1])
        else
            msg( ctx, 2, "Lint does not understand: " *string( sube ))
        end
    end

    if typeof( ex.args[1] ) == Symbol
        resolveArguments( ex.args[1] )
    elseif ex.args[1].head == :tuple
        for i = 1:length(ex.args[1].args)
            resolveArguments( ex.args[1].args[i] )
        end
    else
        resolveArguments( ex.args[1] )
    end
    lintexpr( ex.args[2], ctx )

    popVarScope( ctx )
    pop!( stacktop.localarguments )
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
            lintstr( str, ctx )
            ctx.file = file
            ctx.path = path
            ctx.lineabs = lineabs
        end
    else
        skiplist = Int[]
        if ex.args[1] == :Symbol
            msg( ctx, 2, "You want symbol(), i.e. symbol conversion, instead of a non-existent constructor" )
        elseif ex.args[1] == :String
            msg( ctx, 2, "You want string(), i.e. string conversion, instead of a non-existent constructor" )
        elseif ex.args[1]==:(+)
            lintplus( ex, ctx )
        end

        #splice! allows empty range such as 3:2, it means inserting an array
        # between position 2 and 3, without taking out any value.
        if ex.args[1] == symbol( "splice!" ) && Meta.isexpr( ex.args[3], :(:) ) &&
            length( ex.args[3].args ) == 2 && typeof( ex.args[3].args[1] ) <: Real &&
            typeof( ex.args[3].args[2] ) <: Real && ex.args[3].args[2] < ex.args[3].args[1]
            push!( skiplist, 3 )
        end
        st = 2
        en = length(ex.args)

        if isexpr( ex.args[1], :curly )
            # Dict{Symbol, Int}
            lintexpr( ex.args[1], ctx )
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
        if typeof( ex.args[i] ) <: String ||
            isexpr( ex.args[i], :macrocall ) && ex.args[i].args[1] == symbol( "@sprintf" ) ||
            isexpr( ex.args[i], :call ) && in( ex.args[i].args[1], [
                :replace, :string, :utf8, :utf16, :utf32, :repr, :normalize_string, :join, :chop, :chomp,
                :lpad, :rpad, :strip, :lstrip, :rstrip, :uppercase, :lowercase, :ucfirst, :lcfirst,
                :escape_string, :unescape_string ] )
            msg( ctx, 2, "String uses * to concatenate.")
            break
        end
    end
end
