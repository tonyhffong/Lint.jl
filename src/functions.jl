# deprecation of specialized version of constructors
const deprecated_constructors =
    Dict(:symbol => :Symbol)

const not_constructible = Set([:Union, :Tuple, :Type])

function lintfuncargtype(ex, ctx::LintContext)
    lintexpr(ex, ctx)
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

function istype(ctx::LintContext, x)
    obj = abstract_eval(ctx, x)
    obj !== nothing && isa(obj, Type)
end

# if ctorType isn't symbol("") then we are in the context of
# a constructor for a type. We would check
# * if the function name matches the type name
function lintfunction(ex::Expr, ctx::LintContext; ctorType = Symbol(""), isstaged=false)
    if length(ex.args) == 1 && isa(ex.args[1], Symbol)
        # generic function without methods
        set!(ctx.current, ex.args[1], VarInfo(location(ctx), Function))
        return
    end

    if !isa(ex.args[1], Expr)
        msg(ctx, :E121, ex.args[1], "Lint does not understand the expression")
        return
    end

    fname = Symbol("")
    if ex.args[1].head == :tuple # anonymous
        # do nothing
    elseif isexpr(ex.args[1].args[1], :(.))
        fname = ex.args[1].args[1]
    elseif isa(ex.args[1].args[1], Symbol)
        fname = ex.args[1].args[1]
    elseif !isa(ex.args[1].args[1], Expr)
        msg(ctx, :E121, ex.args[1].args[1], "Lint does not understand the expression")
        return
    elseif ex.args[1].args[1].head == :curly
        fname = ex.args[1].args[1].args[1]
    end
    if isa(fname, Symbol)
        # TODO: warn if it's a using'd thing
        finfo = lookup(ctx.current, fname)
        if finfo == nothing
            set!(ctx.current, fname, VarInfo(location(ctx), Function))
        else
            # TODO: warn if it's something bad
        end
    end

    ctx.scope = string(fname)
    if fname != Symbol("") && !occursin(ctx.file, "deprecate")
        isDeprecated = functionIsDeprecated(ex.args[1])
        if isDeprecated != nothing && !pragmaexists("Ignore deprecated $fname", ctx.current)
            msg(ctx, :E211, ex.args[1], "$(isDeprecated.message); See: " *
                "deprecated.jl $(isDeprecated.line)")
        end
    end

    defer!(ctx.current, MethodInfo(location(ctx), ex, isstaged))
end

function lintfunctionbody(ctx::LintContext, mi::MethodInfo)
    ex = mi.body
    isstaged = mi.isstaged
    oldloc = location(ctx)
    location!(ctx, location(mi))
    temporaryTypes = Any[]
    if isexpr(ex, [:(=), :function]) && isexpr(ex.args[1], :call) &&
       isexpr(ex.args[1].args[1], :curly)
        for i in 2:length(ex.args[1].args[1].args)
            adt = ex.args[1].args[1].args[i]
            if isa(adt, Symbol)
                if istype(ctx, adt)
                    msg(ctx, :E534, adt, "introducing a new name for an implicit " *
                        "argument to the function, use {T<:$(adt)}")
                else
                    push!(temporaryTypes, adt)
                end
            elseif isexpr(adt, :(<:))
                temptype = adt.args[1]
                typeconstraint = adt.args[2]
                if istype(ctx, temptype)
                    msg(ctx, :E536, temptype, "use {T<:...} instead of a known type")
                end
                if istype(ctx, typeconstraint)
                    dt = parsetype(ctx, typeconstraint)
                    if isconcretetype(dt)
                        msg(ctx, :E513, adt, "leaf type as a type constraint makes no sense")
                    end
                end
                push!(temporaryTypes, adt.args[1])
            end
        end
    end

    withcontext(ctx, LocalContext(ctx.current)) do
        # temporaryTypes are the type parameters in curly brackets, make them legal
        # in the current scope
        for t in temporaryTypes
            # TODO: infer when t is a type
            localset!(ctx.current, t, VarInfo(location(ctx)))
        end

        argsSeen = Set{Symbol}()
        optionalposition = 0
        typeRHShints = Dict{Symbol, Any}() # x = 1
        assertions = Dict{Symbol, Any}() # e.g. x::Int

        function resolveArguments(sube::Symbol, position)
            if sube in argsSeen
                msg(ctx, :E331, sube, "duplicate argument")
            elseif sube in keys(ctx.current.localvars)
                msg(ctx, :E331, sube,
                    "function argument duplicates static parameter name")
            end
            if position != 0 && optionalposition != 0
                msg(ctx, :E411, sube, "non-default argument following default arguments")
            end
            push!(argsSeen, sube)
            localset!(ctx.current, sube, VarInfo(location(ctx)))
            if isstaged
                assertions[sube] = Type
            end
            return sube
        end
        function resolveArguments(sube, position)
            # zero position means it's not called at the top level
            if isexpr(sube, :parameters)
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
            elseif isexpr(sube, [:(=), :kw])
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
            elseif isexpr(sube, :(::))
                if length(sube.args) > 1
                    sym = resolveArguments(sube.args[1], 0)
                    if !isstaged
                        if isa(sym, Symbol)
                            dt = parsetype(ctx, sube.args[2])
                            assertions[sym] = dt
                        end
                    end
                    lintfuncargtype(sube.args[2], ctx)
                    return sym
                else
                    lintfuncargtype(sube.args[1], ctx)
                end
            elseif isexpr(sube, :(...))
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
            elseif isexpr(sube, :($))
                lintexpr(sube.args[1], ctx)
            else
                msg(ctx, :E131, sube, "Lint does not understand argument #$(position)")
            end
            return
        end

        params = nothing
        for i = (isexpr(ex.args[1], :call) ? 2 : 1):length(ex.args[1].args)
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
                vi = ctx.current.localvars[s]
                if haskey(assertions, s)
                    dt = parsetype(ctx, assertions[s])
                    vi.typeactual = dt
                    if dt != Any && haskey(typeRHShints, s) && typeRHShints[s] != Any &&
                        !(typeRHShints[s] <: dt)
                        msg(ctx, :E516, s, "type assertion and default seem inconsistent")
                    end
                elseif haskey(typeRHShints, s)
                    vi.typeactual = typeRHShints[s]
                end
            catch
            end
        end

        # TODO: deal with staged functions
        lintexpr(ex.args[2], ctx)
    end

    location!(ctx, oldloc)
    # TODO check cyclomatic complexity?
end

function lintlambda(ex::Expr, ctx::LintContext)
    # TODO: do not duplicate this code in function
    withcontext(ctx, LocalContext(ctx.current)) do
        function resolveArguments(sube)
            if isa(sube, Symbol)
                localset!(ctx.current, sube, VarInfo(location(ctx)))
            elseif sube.head == :parameters
                for kw in sube.args
                    resolveArguments(kw)
                end
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
    end
end

function lintfunctioncall(ex::Expr, ctx::LintContext; inthrow::Bool=false)
    if ex.args[1] == :ccall
        return  # TODO: lint ccall arguments too?
    elseif ex.args[1] == :include && ctx.quoteLvl == 0
        if isa(ex.args[2], AbstractString)
            inclfile = String(ex.args[2])
        else
            # Avoid ERROR level warnings about dynamic includes.
            msg(ctx, :I372, ex.args[2], "unable to follow non-literal include file")
            return
        end

        inclfile = joinpath(ctx.path, inclfile)

        if !ispath(inclfile)
            msg(ctx, :E311, inclfile, "cannot find include file")
            return
        else
            lintinclude(ctx, inclfile)
        end
    else
        if withincurly(ex.args[1]) == :new
            # TODO: lint uses of new?
        else
            lintexpr(ex.args[1], ctx)
        end
        func = abstract_eval(ctx, ex.args[1])

        if func !== nothing && isa(func, Type) && func <: Dict
            lintdict(ex, ctx)
        end

        if haskey(deprecated_constructors, ex.args[1])
            repl = string(deprecated_constructors[ex.args[1]])
            msg(ctx, :I481, ex.args[1], "replace $(ex.args[1])() with $(repl)()")
        end
        if ex.args[1] in not_constructible
            msg(ctx, :W441, "type $(ex.args[1]) is not constructible like this")
        elseif ex.args[1] == :(+)
            lintplus(ex, ctx)
        end

        skiplist = Int[]

        #splice! allows empty range such as 3:2, it means inserting an array
        # between position 2 and 3, without taking out any value.
        if ex.args[1] == Symbol("splice!") && Meta.isexpr(ex.args[3], :(:)) &&
            length(ex.args[3].args) == 2 && isa(ex.args[3].args[1], Real) &&
            isa(ex.args[3].args[2], Real) && ex.args[3].args[2] < ex.args[3].args[1]
            push!(skiplist, 3)
        end

        st = 2
        if ex.args[1] == :ifelse
            lintboolean(ex.args[2], ctx)
            st = 3
        end

        num_args = length(ex.args)

        if isexpr(ex.args[1], :(.))
            lintexpr(ex.args[1], ctx)
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
            if occursin(s,"error") || occursin(s,"exception") || occursin(s,"mismatch") || occursin(s,"fault")
                try
                    dt = parsetype(ctx, ex.args[1])
                    if dt <: Exception && !pragmaexists( "Ignore unthrown " * string(ex.args[1]), ctx.current)
                        msg(ctx, :W448, string(ex.args[1]) * " is an Exception but it is not enclosed in a throw()")
                    end
                catch
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
