function registersymboluse(sym::Symbol, ctx::LintContext)
    if sym == :end
        # TODO: handle this special case elsewhere
        return Any
    end

    lookupresult = BROADCAST(registeruse!, lookup(ctx, sym))

    if isnull(lookupresult)
        if !pragmaexists("Ignore use of undeclared variable $sym", ctx.current) &&
           ctx.quoteLvl == 0
            msg(ctx, :E321, sym, "use of undeclared symbol")
        end
        Any
    else
        return get(lookupresult).typeactual
    end
end

function lintglobal(ex::Expr, ctx::LintContext)
    for sym in ex.args
        if isa(sym, Symbol)
            globalset!(ctx.current, sym, VarInfo(location(ctx), Any))
        elseif !isnull(expand_assignment(sym))
            ea = get(expand_assignment(sym))
            lintassignment(Expr(:(=), ea[1], ea[2]), ctx; isGlobal=true)
        else
            msg(ctx, :E134, sym, "unknown global pattern")
        end
    end
end

function lintlocal(ex::Expr, ctx::LintContext)
    for sube in ex.args
        if isa(sube, Symbol)
            # temporarily set to Union{} until rescued later? this is a safer
            # choice for now.
            set!(ctx.current, sube, VarInfo(location(ctx), Any))
        elseif isexpr(sube, :(=))
            lintassignment(sube, ctx; islocal = true)
        elseif isexpr(sube, :(::))
            sym = sube.args[1]
            @checkisa(ctx, sym, Symbol)
            set!(ctx.current, sym, VarInfo(location(ctx), parsetype(sube.args[2])))
        else
            msg(ctx, :E135, sube, "local declaration not understood by Lint")
        end
    end
end

function resolveLHSsymbol(ex, syms::Array{Any,1}, ctx::LintContext, assertions::Dict{Symbol,Any})
    if isa(ex, Symbol)
        push!(syms, ex)
    elseif isa(ex, Expr)
        if ex.head == :(::)
            if isa(ex.args[1], Symbol)
                assertions[ex.args[1]]=ex.args[2]
            end
            resolveLHSsymbol(ex.args[1], syms, ctx, assertions)
        elseif ex.head == :tuple
            for s in ex.args
                resolveLHSsymbol(s, syms, ctx, assertions)
            end
        elseif ex.head == :(.) ||   # a.b = something
            ex.head == :ref ||      # a[b] = something
            ex.head == :($)         # :($(esc(name)) = something)
            push!(syms, ex)
            lintexpr(ex, ctx)
            return
        else
            msg(ctx, :I171, ex, "LHS in assignment not understood by Lint")
        end
    else
        msg(ctx, :I171, ex, "LHS in assignment not understood by Lint")
    end
end

function lintassignment(ex::Expr, ctx::LintContext; islocal = false, isConst=false, isGlobal=false, isForLoop=false) # is it a local decl & assignment?
    lhs = ex.args[1]

    # lower curly
    rhstype = Any
    if isexpr(lhs, :curly)
        isConst = true
        lhs = withincurly(lhs)
        rhstype = Type
        # TODO: lint the RHS too
    else
        lintexpr(ex.args[2], ctx)
    end

    syms = Any[]
    assertions = Dict{Symbol, Any}()
    resolveLHSsymbol(lhs, syms, ctx, assertions)
    tuplelen = length(syms)
    lhsIsTuple = Meta.isexpr(lhs, :tuple)
    if rhstype == Any
        rhstype = guesstype(ex.args[2], ctx)
    end

    if rhstype == Union{}
        msg(ctx, :E539, lhs, "assigning an error to a variable")
    elseif isForLoop && isa(rhstype, Type)
        if rhstype <: Number
            msg(ctx, :I672, "iteration works for a number but it may be a typo")
        end

        rhstype = StaticTypeAnalysis.eltype(rhstype)

        if lhsIsTuple
            computedlength = StaticTypeAnalysis.length(rhstype)
            if !isnull(computedlength) && get(computedlength) ≠ tuplelen
                msg(ctx, :I474, rhstype, "iteration generates tuples, " *
                    "$tuplelen of $(get(computedlength)) variables used")
            end
        end
    elseif isa(rhstype, Type) && lhsIsTuple
        computedlength = StaticTypeAnalysis.length(rhstype)
        if !isnull(computedlength)
            if get(computedlength) < tuplelen
                msg(ctx, :E418, rhstype, "RHS is a tuple, $tuplelen of " *
                    "$(get(computedlength)) variables used")
            elseif get(computedlength) > tuplelen
                msg(ctx, :W546, rhstype, string(
                    "implicitly discarding values, $tuplelen of ",
                    get(computedlength), " used"))
            end
        end
    end

    for (symidx, s) in enumerate(syms)
        if !isa(s, Symbol) # a.b or a[b]
            if isexpr(s, [:(.), :ref])
                containertype = guesstype(s.args[1], ctx)
                if isa(unwrap_unionall(containertype), DataType) &&
                   !isabstract(containertype) &&
                   !unwrap_unionall(containertype).mutable
                    msg(ctx, :E525, s.args[1], "is of an immutable type $(containertype)")
                end
            end

            continue
        end
        if string(s) == ctx.scope && !islocal
            msg(ctx, :W355, ctx.scope, "conflicts with function name")
        end
        if s == :call
            msg(ctx, :E332, s, "should not be used as a variable name")
        end

        # +=, -=, *=, etc.
        if ex.head != :(=)
            registersymboluse(s, ctx)
        end
        vi = VarInfo(location(ctx))
        # @lintpragma("Ignore incompatible type comparison")
        if isa(rhstype, Type) && !lhsIsTuple
            rhst = rhstype
        elseif isa(rhstype, Type)
            rhst = StaticTypeAnalysis.typeof_nth(rhstype, symidx)
        else
            rhst = Any
        end
        try
            if haskey(assertions, s)
                dt = parsetype(assertions[s])
                vi.typeactual = dt
                if typeintersect(dt, rhst) == Union{}
                    msg(ctx, :I572, "assert $(s) type= $(dt) but assign a value of " *
                        "$(rhst)")
                end
            elseif rhst != Any && !isForLoop
                vi.typeactual = rhst
            end
        catch er
            msg(ctx, :W251, ex, "$(er); Symbol=$(s); rhstype=$(rhst)")
        end

        if isGlobal || isConst || istoplevel(ctx.current)
            globalset!(ctx.current, s, vi)
            # TODO: guess type and use that type information
        elseif islocal
            localset!(ctx.current, s, vi)
        else
            set!(ctx.current, s, vi)
        end
    end
end
