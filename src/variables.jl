function popVarScope(ctx::LintContext; checkargs::Bool=false)
    tmpline = ctx.line
    stacktop = ctx.callstack[end]
    unused = setdiff(keys(stacktop.localvars[end]), stacktop.localusedvars[end])
    if ctx.quoteLvl == 0
        for v in unused
            if !pragmaexists("Ignore unused $v", ctx) && v != :_
                ctx.line = stacktop.localvars[end][v].line
                msg(ctx, :W341, v, "local variable declared but not used")
            end
        end
        if checkargs
            unusedargs = setdiff(keys(stacktop.localarguments[end]), stacktop.localusedargs[end])
            for v in unusedargs
                if !pragmaexists("Ignore unused $v", ctx) && v != :_
                    ctx.line = stacktop.localarguments[end][v].line
                    msg(ctx, :I382, v, "argument declared but not used")
                end
            end
        end
    end

    union!(stacktop.oosvars, setdiff(keys(stacktop.localvars[end]), keys(stacktop.localvars[1])))
    pop!(stacktop.localvars)
    pop!(stacktop.localusedvars)
    ctx.line = tmpline
end

function pushVarScope(ctx::LintContext)
    push!(ctx.callstack[end].localvars, Dict{Symbol, Any}())
    push!(ctx.callstack[end].localusedvars, Set{Symbol}())
end

# returns
# :var - a non-Type value
# :Type
# :Any - don't know, could be either (with lint warnings, if strict)

# if strict == false, it won't generate lint warnings, just return :Any

function registersymboluse(sym::Symbol, ctx::LintContext, strict::Bool=true)
    stacktop = ctx.callstack[end]

    #println(sym)
    #println(stacktop.localvars)
    for i in length(stacktop.localvars):-1:1
        if haskey(stacktop.localvars[i], sym)
            push!(stacktop.localusedvars[i], sym)
            # TODO: This is not quite right. We need to check type
            # on the sym. If it's Type, return :Type
            # if Any, return :Any
            # otherwise, :var
            return :var
        end
    end

    for i in length(stacktop.localarguments):-1:1
        if haskey(stacktop.localarguments[i], sym)
            push!(stacktop.localusedargs[i], sym)
            # TODO: we need to check type
            return :var
        end
    end

    # a bunch of whitelist to just grandfather-in
    if sym in knowntypes
        return :Type
    end
    if sym in knownsyms
        return :var
    end

    # Move up call stack, looking at global declarations
    for i in length(ctx.callstack):-1:1
        if in(sym, ctx.callstack[i].types)
            return :Type
        elseif haskey(ctx.callstack[i].declglobs, sym) ||
               in(sym, ctx.callstack[i].functions) ||
               in(sym, ctx.callstack[i].modules) ||
               in(sym, ctx.callstack[i].imports)
            return :var
        end
    end

    # Fall back to dynamic evaluation in Main
    result = dynamic_imported_binding_type(sym)

    if strict && result === :Any &&
       !pragmaexists("Ignore use of undeclared variable $sym", ctx)
        if ctx.quoteLvl == 0
            msg(ctx, :E321, sym, "use of undeclared symbol")
        elseif ctx.isstaged
            msg(ctx, :I371, sym, "use of undeclared symbol")
        end
    end
    return result
end

function lintglobal(ex::Expr, ctx::LintContext)
    for sym in ex.args
        if isa(sym, Symbol)
            if !haskey(ctx.callstack[end].declglobs, sym)
                register_global(
                    ctx,
                    sym,
                    Dict{Symbol,Any}(:file=>ctx.file, :line=>ctx.line)
               )
            end
        elseif isexpr(sym, ASSIGN_OPS)
            lintassignment(sym, sym.head, ctx; isGlobal=true)
        else
            msg(ctx, :E134, sym, "unknown global pattern")
        end
    end
end

function lintlocal(ex::Expr, ctx::LintContext)
    n = length(ctx.callstack[end].localvars)
    for sube in ex.args
        if isa(sube, Symbol)
            ctx.callstack[end].localvars[n][sube] = VarInfo(ctx.line)
        elseif isexpr(sube, :(=))
            lintassignment(sube, :(=), ctx; islocal = true)
        elseif isexpr(sube, :(::))
            sym = sube.args[1]
            vi = VarInfo(ctx.line)
            try
                dt = stdlibobject(sube.args[2])
                if !isnull(dt) && isa(get(dt), Type)
                    vi.typeactual = get(dt)
                else
                    vi.typeexpr = sube.args[2]
                end
            catch
                vi.typeexpr = sube.args[2]
            end
            ctx.callstack[end].localvars[n][sym] = vi
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

function lintassignment(ex::Expr, assign_ops::Symbol, ctx::LintContext; islocal = false, isConst=false, isGlobal=false, isForLoop=false) # is it a local decl & assignment?
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
        msg(ctx, :E539, rhstype, "assigning an error to a variable")
    elseif isForLoop && isa(rhstype, Type)
        if rhstype <: Number
            msg(ctx, :I672, "iteration works for a number but it may be a typo")
        end

        if rhstype <: Union{Tuple,Set,Array,Range,Enumerate}
            rhstype = StaticTypeAnalysis.eltype(rhstype)
        elseif rhstype <: Associative
            rhstype = Tuple{keytype(rhstype), valuetype(rhstype)}
        end

        # TODO: only when LHS is tuple
        if rhstype <: Tuple
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
        elseif in(s, knownsyms)
            if in(s, [:e, :pi, :eu, :catalan, :eulergamma, :golden, :π, :γ, :φ])
                if ctx.file != "constants.jl"
                    msg(ctx, :W351, s, "redefining mathematical constant")
                end
            else
                msg(ctx, :I392, s, "local variable might cause confusion with a " *
                    "synonymous export from Base")
            end
        end

        # +=, -=, *=, etc.
        if ex.head != :(=)
            registersymboluse(s, ctx)
        end
        vi = VarInfo(ctx.line)
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
            if haskey(assertions, s)
                vi.typeexpr = assertions[s]
            end
        end

        if islocal
            ctx.callstack[end].localvars[end][s] = vi
        else # it's not explicitly local, but it could be!
            found = false
            for i in length(ctx.callstack[end].localvars):-1:1
                if haskey(ctx.callstack[end].localvars[i], s)
                    found = true
                    prevvi = ctx.callstack[end].localvars[i][s]
                    if isa(vi.typeactual, Type) && isa(prevvi.typeactual, Type) &&
                        vi.typeactual <: Number && prevvi.typeactual <: Number && assign_ops != :(=)
                        if length(prevvi.typeactual.parameters) == 0
                        else
                        end
                        continue
                    elseif isa(vi.typeactual, Type) && isa(prevvi.typeactual, Type) &&
                        vi.typeactual <: Number && prevvi.typeactual <: Array && assign_ops != :(=)

                        continue
                    elseif vi.typeactual ≠ Any && !isa(vi.typeactual, Symbol) && !(vi.typeactual <: prevvi.typeactual) &&
                        !(vi.typeactual <: AbstractString && prevvi.typeactual <: vi.typeactual) &&
                        !pragmaexists("Ignore unstable type variable $(s)", ctx)
                        msg(ctx, :W545, s, "previously used variable has apparent type " *
                            "$(prevvi.typeactual), but now assigned $(vi.typeactual)")
                    end
                    ctx.callstack[end].localvars[i][s] = vi
                end
            end

            if !found && in(s, ctx.callstack[end].oosvars)
                msg(ctx, :I482, s, "used in a local scope. Improve readability by using " *
                    "'local' or another name")
            end

            if !found && !isGlobal && !haskey(ctx.callstack[end].declglobs, s)
                for i in length(ctx.callstack)-1:-1:1
                    if haskey(ctx.callstack[i].declglobs, s) && length(string(s)) > 4 &&
                            !in(s, [:value, :index, :fname, :fargs])
                        src = string(ctx.callstack[i].declglobs[s])
                        l = split(src, "\n")
                        splice!(l, 1)
                        src = join(l, "\n")
                        msg(ctx, :I391, s, "also a global from $(src)")
                        break;
                    end
                end
            end

            if !found
                ctx.callstack[end].localvars[1][s] = vi
            end
        end
        if isGlobal || isConst || (ctx.functionLvl + ctx.macroLvl == 0 && ctx.callstack[end].isTop)
            register_global(
                ctx,
                s,
                Dict{Symbol,Any}(:file => ctx.file, :line => ctx.line)
           )
        end
    end
end
