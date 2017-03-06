const commoncollections = [
    Array, AbstractArray, BitArray, Set, Associative]
const commoncollmethods = Dict{Symbol, Set{Type}}()

# deprecation of specialized version of constructors
const deprecated_constructors =
    Dict(:symbol => :Symbol)

const not_constructible = Set([:Union, :Tuple, :Type])

function initcommoncollfuncs()
    global commoncollmethods
    for t in commoncollections
        ms = methodswith(t)
        for m in ms
            str = string(m)
            mtch = match(r"^[a-zA-Z_][a-zA-Z0-9_]*(!)?", str)
            if mtch != nothing
                if in(mtch.match, [
                        "hash", "show", "rand", "isequal", "convert", "serialize", "isless",
                        "writemime", "write", "Dict", "eltype", "push!"
                    ])
                    continue
                end
                s = Symbol(mtch.match)
                if !haskey(commoncollmethods, s)
                    commoncollmethods[s] = Set{Type}()
                end
                push!(commoncollmethods[s], t)
            end
        end
    end
    for (k,v) in commoncollmethods
        if length(v) < 2
            delete!(commoncollmethods, k)
        end
    end
    # ADD COMMON FUNCTIONS WITH EASILY-MISTAKEN SIGNATURES HERE
    commoncollmethods[:(append!)] = Set{Type}()
end

function lintfuncargtype(ex, ctx::LintContext)
    if isexpr(ex, :curly)
        st = 2
        en = 1
        if ex.args[1] == :Array
            en = 2
        elseif ex.args[1] == :Dict
            en = 3
        end
        for i in st:en
            if in(ex.args[i], [:Number])
                msg(ctx, :E533, ex, "type parameters are invariant, try f{T<:Number}(x::T)...")
            end
        end
    end
end

# if ctorType isn't symbol("") then we are in the context of
# a constructor for a type. We would check
# * if the function name matches the type name
function lintfunction(ex::Expr, ctx::LintContext; ctorType = Symbol(""), isstaged=false)
    if length(ex.args) == 1 && isa(ex.args[1], Symbol)
        # generic function without methods
        return
    end

    if !isa(ex.args[1], Expr)
        msg(ctx, :E121, ex.args[1], "Lint does not understand the expression")
        return
    end

    if !isempty(ex.args[1].args) && ex.args[1].args[1]==:eval # extending eval(m,x) = ... in module. don't touch it.
        return
    end

    temporaryTypes = Any[]

    fname = Symbol("")
    if ex.args[1].head == :tuple # anonymous
        # do nothing
    elseif isexpr(ex.args[1].args[1], :(.))
        fname = ex.args[1].args[1]
        push!(ctx.callstack[end].functions, fname.args[end])
    elseif isa(ex.args[1].args[1], Symbol)
        fname = ex.args[1].args[1]
        push!(ctx.callstack[end].functions, fname)
    elseif !isa(ex.args[1].args[1], Expr)
        msg(ctx, :E121, ex.args[1].args[1], "Lint does not understand the expression")
        return
    elseif ex.args[1].args[1].head == :curly
        fname = ex.args[1].args[1].args[1]
        push!(ctx.callstack[end].functions, fname)
        for i in 2:length(ex.args[1].args[1].args)
            adt = ex.args[1].args[1].args[i]
            if isa(adt, Symbol)
                if in(adt, knowntypes)
                    msg(ctx, :E534, adt, "introducing a new name for an implicit " *
                        "argument to the function, use {T<:$(adt)}")
                else
                    push!(temporaryTypes, adt)
                end
            elseif isexpr(adt, :(<:))
                temptype = adt.args[1]
                typeconstraint = adt.args[2]
                if in(temptype, knowntypes)
                    msg(ctx, :E536, temptype, "use {T<:...} instead of a known type")
                end
                if in(typeconstraint, knowntypes)
                    dt = parsetype(typeconstraint)
                    if isleaftype(dt)
                        msg(ctx, :E513, adt, "leaf type as a type constraint makes no sense")
                    end
                end
                push!(temporaryTypes, adt.args[1])
            end
        end
    elseif ex.args[1].args[1].head == :($)
        lintexpr(ex.args[1].args[1].args[1], ctx)
    end

    ctx.scope = string(fname)
    if fname != Symbol("") && !contains(ctx.file, "deprecate")
        isDeprecated = functionIsDeprecated(ex.args[1])
        if isDeprecated != nothing && !pragmaexists("Ignore deprecated $fname", ctx)
            msg(ctx, :E211, ex.args[1], "$(isDeprecated.message); See: " *
                "deprecated.jl $(isDeprecated.line)")
        end
    end

    if ctx.macroLvl == 0 && ctx.functionLvl == 0
        pushcallstack(ctx)
    else
        push!(ctx.callstack[end].localarguments, Dict{Symbol,Any}())
        push!(ctx.callstack[end].localusedargs, Set{Symbol}())
    end
    ctx.functionLvl = ctx.functionLvl + 1
    # grab the arguments. push a new stack, populate the new stack's argument fields and process the block
    stacktop = ctx.callstack[end]
    # temporaryTypes are the type parameters in curly brackets, make them legal in the current scope
    union!(stacktop.types, temporaryTypes)

    argsSeen = Set{Symbol}()
    optionalposition = 0
    typeRHShints = Dict{Symbol, Any}() # x = 1
    assertions = Dict{Symbol, Any}() # e.g. x::Int

    resolveArguments = (sube, position) -> begin # zero position means it's not called at the top level
        if isa(sube, Symbol)
            if in(sube, argsSeen)
                msg(ctx, :E331, sube, "duplicate argument")
            end
            if position != 0 && optionalposition != 0
                msg(ctx, :E411, sube, "non-default argument following default arguments")
            end
            push!(argsSeen, sube)
            stacktop.localarguments[end][sube] = VarInfo(ctx.line)
            if isstaged
                assertions[sube] = Type
            end
            return sube
        elseif sube.head == :parameters
            for (j,kw) in enumerate(sube.args)
                if isexpr(kw, :(...))
                    if j != length(sube.args)
                        msg(ctx, :E412, kw, "named ellipsis ... can only be the last argument")
                        return
                    end
                    sym = resolveArguments(kw, 0)
                    if isa(sym, Symbol)
                        if isstaged
                            assertions[sym] = Type
                        else
                            # This may change to Array{(Symbol,Any), 1} in the future
                            assertions[sym] = Array{Any,1}
                        end
                    end
                    return
                elseif !isexpr(kw, [:(=), :kw])
                    msg(ctx, :E423, kw, "named keyword argument must have a default")
                    return
                else
                    resolveArguments(kw, 0)
                end
            end
        elseif sube.head == :(=) || sube.head == :kw
            if position != 0
                optionalposition = position
            end
            lintexpr(sube.args[2], ctx)
            sym = resolveArguments(sube.args[1], 0)
            if !isstaged
                rhstype = guesstype(sube.args[2], ctx)
                if isa(sym, Symbol)
                    typeRHShints[sym] = rhstype
                end
            end
        elseif sube.head == :(::)
            if length(sube.args) > 1
                sym = resolveArguments(sube.args[1], 0)
                if !isstaged
                    if isa(sym, Symbol)
                        dt = Any
                        try
                            dt = parsetype(sube.args[2])
                            assertions[sym] = dt
                        catch er
                            msg(ctx, :E139, sube.args[2], "Lint fails to parse type: $(er)")
                        end
                    end
                end
                lintfuncargtype(sube.args[2], ctx)
                return sym
            else
                lintfuncargtype(sube.args[1], ctx)
            end
        elseif sube.head == :(...)
            if position != 0 && position != length(ex.args[1].args)
                msg(ctx, :E413, sube, "positional ellipsis ... can only be the last argument")
            end
            sym = resolveArguments(sube.args[1], 0)
            if isa(sym, Symbol)
                if isstaged
                    assertions[sym] = Tuple{Vararg{Type}}
                elseif haskey(assertions, sym)
                    assertions[sym] = Tuple{Vararg{assertions[sym]}}
                else
                    assertions[sym] = Tuple{Vararg{Any}}
                end
            end
        elseif sube.head == :($)
            lintexpr(sube.args[1], ctx)
        else
            msg(ctx, :E131, sube, "Lint does not understand argument #$(position)")
        end
        return nothing
    end

    params = nothing
    for i = (fname == Symbol("") ? 1 : 2):length(ex.args[1].args)
        if isexpr(ex.args[1].args[i], :parameters)
            params = ex.args[1].args[i]
            continue
        end
        resolveArguments(ex.args[1].args[i], i)
    end
    if params != nothing
        resolveArguments(params, 1)
    end

    for s in argsSeen
        try
            vi = stacktop.localarguments[end][s]
            if haskey(assertions, s)
                dt = parsetype(assertions[s])
                vi.typeactual = dt
                if dt != Any && haskey(typeRHShints, s) && typeRHShints[s] != Any &&
                    !(typeRHShints[s] <: dt)
                    msg(ctx, :E516, s, "type assertion and default seem inconsistent")
                end
            elseif haskey(typeRHShints, s)
                vi.typeactual = typeRHShints[s]
            end
        end
    end

    prev_isstaged = ctx.isstaged
    ctx.isstaged = isstaged
    pushVarScope(ctx)
    lintexpr(ex.args[2], ctx)

    if ctorType != Symbol("") && fname != ctorType &&
            in(:new, ctx.callstack[end].calledfuncs)
        msg(ctx, :E517, fname, "constructor-like function name doesn't match type $(ctorType)")
    end
    if ctorType != Symbol("") && fname == ctorType
        t = guesstype(ex.args[2], ctx)
        if isa(t, Type)
            if t ≠ Any && t.name.name != ctorType
                msg(ctx, :E611, "constructor doesn't seem to return the constructed object")
            end
        elseif t != ctorType
            msg(ctx, :E611, "constructor doesn't seem to return the constructed object")
        end
    end
    popVarScope(ctx, checkargs=true)

    ctx.functionLvl = ctx.functionLvl - 1
    # TODO check cyclomatic complexity?
    if ctx.macroLvl == 0 && ctx.functionLvl == 0
        popcallstack(ctx)
    else
        pop!(ctx.callstack[end].localarguments)
        pop!(ctx.callstack[end].localusedargs)
    end
    ctx.scope = ""
    ctx.isstaged = prev_isstaged
end

function lintlambda(ex::Expr, ctx::LintContext)
    stacktop = ctx.callstack[end]
    push!(stacktop.localarguments, Dict{Symbol, Any}())
    push!(stacktop.localusedargs, Set{Symbol}())
    pushVarScope(ctx)
    # check for conflicts on lambda arguments
    checklambdaarg = (sym)->begin
        for i in length(stacktop.localvars):-1:1
            if haskey(stacktop.localvars[i], sym)
                msg(ctx, :W352, sym, "lambda argument conflicts with a local variable")
                break
            end
        end
        for i in length(stacktop.localarguments):-1:1
            if haskey(stacktop.localarguments[i], sym)
                msg(ctx, :W353, sym, "lambda argument conflicts with an argument")
                break
            end
        end
        for i in length(ctx.callstack):-1:1
            if haskey(ctx.callstack[i].declglobs, sym)
                msg(ctx, :W354, sym, "lambda argument conflicts with an declared " *
                    "global from $(ctx.callstack[i].declglobs[sym])")
            end
        end
        stacktop.localarguments[end][sym] = VarInfo(ctx.line)
    end

    resolveArguments = (sube) -> begin
        if isa(sube, Symbol)
            checklambdaarg(sube)
            stacktop.localarguments[end][sube] = VarInfo(ctx.line)
        #= # until lambda supports named args, keep this commented
        elseif sube.head == :parameters
            for kw in sube.args
                resolveArguments(kw)
            end
        =#
        elseif isexpr(sube, Symbol[:(=), :(kw), :(::), :(...)])
            if sube.head == :(=) || sube.head == :kw
                resolveArguments(sube.args[1])
            elseif sube.head == :(::)
                if length(sube.args) > 1
                    resolveArguments(sube.args[1])
                end
            elseif sube.head == :(...)
                resolveArguments(sube.args[1])
            end
        else
            msg(ctx, :E132, sube, "Lint does not understand argument")
        end
    end

    if isa(ex.args[1], Symbol)
        resolveArguments(ex.args[1])
    elseif isexpr(ex.args[1], :tuple)
        for i = 1:length(ex.args[1].args)
            resolveArguments(ex.args[1].args[i])
        end
    else
        resolveArguments(ex.args[1])
    end
    lintexpr(ex.args[2], ctx)

    popVarScope(ctx, checkargs=true)
    pop!(stacktop.localarguments)
    pop!(stacktop.localusedargs)
end

function lintfunctioncall(ex::Expr, ctx::LintContext; inthrow::Bool=false)
    if ex.args[1] == :include
        if isa(ex.args[2], AbstractString)
            inclfile = string(ex.args[2])
        else
            inclfile = ""
            try
                # TODO: not a good idea...
                inclfile = eval(ex.args[2])
            catch
                inclfile = string(ex.args[2])
                # Avoid ERROR level warnings about dynamic includes.
                msg(ctx, :I372, inclfile, "unable to follow non-literal include file")
                return
            end
        end

        inclfile = joinpath(ctx.path, inclfile)

        if !ispath(inclfile)
            msg(ctx, :E311, inclfile, "cannot find include file")
            return
        else
            #println("include: ", inclfile)
            lintinclude(ctx, inclfile)
        end
    else
        if isexpr(ex.args[1], :curly)
            lintcurly(ex.args[1], ctx)
        end

        if ex.args[1] == :Dict || isexpr(ex.args[1], :curly) && ex.args[1].args[1] == :Dict
            lintdict(ex, ctx)
            return
        end
        known=false

        versionreachable = ctx.versionreachable(VERSION)
        if versionreachable && haskey(deprecated_constructors, ex.args[1])
            repl = string(deprecated_constructors[ex.args[1]])
            suffix = ""
            if contains(repl, "Int")
                suffix = ", or some of the other explicit conversion functions. " *
                    "(round, trunc, etc...)"
            end
            msg(ctx, :I481, ex.args[1], "replace $(ex.args[1])() with $(repl)()$(suffix)")
        end
        if ex.args[1] in not_constructible
            msg(ctx, :W441, "type $(ex.args[1]) is not constructible like this")
        elseif ex.args[1] == :(+)
            lintplus(ex, ctx)
            known = true
        end

        skiplist = Int[]

        if isa(ex.args[1], Symbol) && haskey(commoncollmethods, ex.args[1])
            known=true
            s = ex.args[1]
            typesig = Any[]
            for i in 2:length(ex.args)
                if !isexpr(ex.args[i], :kw) && !isexpr(ex.args[i], :parameters)
                    push!(typesig, guesstype(ex.args[i], ctx))
                end
            end
            if all(x->isa(x,Tuple) && all(y->y!=Any, x) || x != Any, typesig)
                try
                    which(getfield(Main, s), tuple(typesig...))
                catch er
                    msg(ctx, :I281, s, "$(er); Signature: $(tuple(typesig...))")
                end
            end
        end

        #splice! allows empty range such as 3:2, it means inserting an array
        # between position 2 and 3, without taking out any value.
        if ex.args[1] == Symbol("splice!") && Meta.isexpr(ex.args[3], :(:)) &&
            length(ex.args[3].args) == 2 && isa(ex.args[3].args[1], Real) &&
            isa(ex.args[3].args[2], Real) && ex.args[3].args[2] < ex.args[3].args[1]
            push!(skiplist, 3)
        end

        if ex.args[1] == :new
            tname = Symbol(ctx.scope)
            for i = length(ctx.callstack):-1:1
                if haskey(ctx.callstack[i].typefields, tname)
                    fields = ctx.callstack[i].typefields[tname]
                    if 0 < length(ex.args) - 1 < length(fields)
                        if !pragmaexists("Ignore short new argument", ctx, deep=false)
                            msg(ctx, :I671, "new is provided with fewer arguments than fields")
                        end
                    elseif length(fields) < length(ex.args) - 1
                        msg(ctx, :E435, "new is provided with more arguments than fields")
                    end
                    break
                end
            end
            known=true
        end

        st = 2
        if ex.args[1] == :ifelse
            lintboolean(ex.args[2], ctx)
            st = 3
            known = true
        end

        if !known && isa(ex.args[1], Symbol)
            registersymboluse(ex.args[1], ctx, false)
        end

        num_args = length(ex.args)

        if isexpr(ex.args[1], :(.))
            lintexpr(ex.args[1], ctx)
        elseif isa(ex.args[1], Symbol)
            push!(ctx.callstack[end].calledfuncs, ex.args[1])
        end


        if ex.args[1] in COMPARISON_OPS
            if num_args == 3
                #reuse lintcomparison by synthetically construct the expr
                lintcomparison(Expr(:comparison, ex.args[2], ex.args[1], ex.args[3]), ctx)
            elseif !isexpr(ex.args[2], :(...))
                msg(ctx, :E132, ex.args[2], "Lint does not understand argument")
            end
        end

        if !inthrow && isa(ex.args[1], Symbol)
            s = lowercase(string(ex.args[1]))
            if contains(s,"error") || contains(s,"exception") || contains(s,"mismatch") || contains(s,"fault")
                try
                    dt = parsetype(ex.args[1])
                    if dt <: Exception && !pragmaexists( "Ignore unthrown " * string(ex.args[1]), ctx)
                        msg(ctx, :W448, string(ex.args[1]) * " is an Exception but it is not enclosed in a throw()")
                    end
                end
            end
        end

        if !inthrow && ex.args[1] == :throw && isexpr(ex.args[2], :call)
            lintfunctioncall(ex.args[2], ctx, inthrow=true)
        else
            for i in st:num_args
                if in(i, skiplist)
                    continue
                elseif isexpr(ex.args[i], :parameters)
                    for kw in ex.args[i].args
                        if isexpr(kw, :(...))
                            lintexpr(kw.args[1], ctx)
                        elseif ispairexpr(kw)
                            lintexpr(lexicalfirst(kw), ctx)
                            lintexpr(lexicallast(kw), ctx)
                        elseif isa(kw, Expr) && length(kw.args) == 2
                            lintexpr(kw.args[2], ctx)
                        elseif isa(kw, Symbol)
                            lintexpr(kw, ctx)
                        else
                            msg(ctx, :E133, kw, "unknown keyword pattern")
                        end
                    end
                elseif isexpr(ex.args[i], :kw)
                    lintexpr(ex.args[i].args[2], ctx)
                else
                    lintexpr(ex.args[i], ctx)
                end
            end
        end
    end
end

function lintplus(ex::Expr, ctx::LintContext)
    for i in 2:length(ex.args)
        if guesstype(ex.args[i], ctx) <: AbstractString
            msg(ctx, :E422, "string uses * to concatenate")
            break
        end
    end
end
