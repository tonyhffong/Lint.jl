# type definition lint code

function linttype(ex::Expr, ctx::LintContext)
    if ctx.quoteLvl > 0
        return  # do not lint types in quotes, see issue 166
    end

    @checktoplevel(ctx, "type")
    typeparams = Symbol[]

    # TODO: this duplicates the code in functions.jl
    processCurly = (sube)->begin
        for i in 2:length(sube.args)
            adt = sube.args[i]
            if isa(adt, Symbol)
                foundobj = lookup(ctx, adt)
                if !isnull(foundobj) && get(foundobj).typeactual <: Type
                    msg(ctx, :I393, adt, "using an existing type as type parameter name is probably a typo")
                end
                # TODO: review all uses of this function
                push!(typeparams, adt)
            elseif isexpr(adt, :(<:))
                temptype = adt.args[1]
                typeconstraint = adt.args[2]

                if temptype != :T
                    foundobj = lookup(ctx, temptype)
                    if !isnull(foundobj) && get(foundobj).typeactual <: Type
                        msg(ctx, :E538, temptype, "known type in parametric data type, " *
                            "use {T<:...}")
                    end
                end
                if istype(ctx, typeconstraint)
                    dt = parsetype(ctx, typeconstraint)
                    if isa(dt, Type) && isleaftype(dt)
                        msg(ctx, :E513, adt, "leaf type as a type constraint makes no sense")
                    end
                end
                push!(typeparams, temptype)
            end
        end
    end

    tname = Symbol("")
    if isa(ex.args[2], Symbol)
        tname = ex.args[2]
    elseif isexpr(ex.args[2], :curly)
        tname = ex.args[2].args[1]
        processCurly(ex.args[2])
    elseif isexpr(ex.args[2], :(<:))
        if isa(ex.args[2].args[1], Symbol)
            tname = ex.args[2].args[1]
        elseif isexpr(ex.args[2].args[1], :curly)
            tname = ex.args[2].args[1].args[1]
            processCurly(ex.args[2].args[1])
        end
    end
    if tname != Symbol("")
        if islower(string(tname)[1])
            msg(ctx, :I771, tname, "type names should start with an upper case")
        end
        set!(ctx.current, tname, VarInfo(location(ctx), Type))
    end

    fields = Any[]
    funcs = Any[]

    for def in ex.args[3].args
        if isa(def, LineNumberNode)
            ctx.line = def.line-1
        elseif isa(def, Symbol)
            # it means Any, probably not a very efficient choice
            if !pragmaexists("Ignore untyped field $(def)", ctx.current, deep=false)
                msg(ctx, :I691, def, "a type is not given to the field which can be slow")
            end
            push!(fields, (def, Any))
        elseif isexpr(def, :macrocall) && def.args[1] == Symbol("@lintpragma")
            lintlintpragma(def, ctx)
        elseif isexpr(def, :call) && def.args[1] == Symbol("lintpragma")
            lintlintpragma(def, ctx)
            msg(ctx, :E425, "use lintpragma macro inside type declaration")
        elseif isexpr(def, :(::))
            if isexpr(def.args[2], :curly) && def.args[2].args[1] == :Array && length(def.args[2].args) <= 2 &&
                !pragmaexists("Ignore dimensionless array field $(def.args[1])", ctx.current, deep=false)
                msg(ctx, :I692, def.args[1], "array field has no dimension which can be slow")
            end
            push!(fields, (def.args[1], def.args[2]))
        elseif isexpr(def, :(=)) && isexpr(def.args[1], :call) || isexpr(def, :function)
            # curly bracket doesn't belong here. catch it first before linting the rest of the function body
            if def.args[1].head == :tuple
                # if julia supports anonymous constructor syntactic sugar, remove this, and make sure ctx.scope is type name
                msg(ctx, :E417, "anonymous function inside type definition")
            end
            push!(funcs, (def, ctx.line))
        end
    end

    for f in funcs
        ctx.line = f[2]
        lintfunction(f[1], ctx; ctorType = tname)
    end
end

function linttypealias(ex::Expr, ctx::LintContext)
    # TODO: make this just part of lintassignment
    sym = withincurly(ex.args[1])
    @checkisa(ctx, sym, Symbol)
    set!(ctx.current, sym, VarInfo(location(ctx), Type))
end

function lintabstract(ex::Expr, ctx::LintContext)
    sym = withincurly(ex.args[1])
    if isa(sym, Symbol)
        set!(ctx.current, sym, VarInfo(location(ctx), Type))
    elseif isexpr(ex.args[1], :(<:))
        sym = withincurly(ex.args[1].args[1])
        @checkisa(ctx, sym, Symbol)
        set!(ctx.current, sym, VarInfo(location(ctx), Type))
    end
end

function lintbitstype(ex::Expr, ctx::LintContext)
    @checkisa(ctx, ex.args[2], Symbol)
    set!(ctx.current, ex.args[2], VarInfo(location(ctx), Type))
end
