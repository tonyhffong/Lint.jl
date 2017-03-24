# type definition lint code

function linttype(ex::Expr, ctx::LintContext)
    if ctx.macroLvl ==0 && ctx.functionLvl == 0
        pushcallstack(ctx)
    end
    typeparams = Symbol[]

    # TODO: this duplicates the code in functions.jl
    processCurly = (sube)->begin
        for i in 2:length(sube.args)
            adt = sube.args[i]
            if isa(adt, Symbol)
                typefound = isstandardtype(adt)
                if typefound && adt != :T
                    msg(ctx, :I393, adt, "using an existing type as type parameter name is probably a typo")
                end
                # TODO: review all uses of this function
                addtype!(ctx.callstack[end], adt)
                push!(typeparams, adt)
            elseif isexpr(adt, :(<:))
                temptype = adt.args[1]
                typeconstraint = adt.args[2]

                if temptype != :T
                    typefound = isstandardtype(temptype)
                    if typefound
                        msg(ctx, :E538, temptype, "known type in parametric data type, " *
                            "use {T<:...}")
                    end
                end
                if isstandardtype(typeconstraint)
                    dt = parsetype(typeconstraint)
                    if isa(dt, Type) && isleaftype(dt)
                        msg(ctx, :E513, adt, "leaf type as a type constraint makes no sense")
                    end
                end
                addtype!(ctx.callstack[end], temptype)
                push!(typeparams, temptype)
            end
        end
    end

    tname = Symbol("")
    if isa(ex.args[2], Symbol)
        tname = ex.args[2]
    elseif isexpr(ex.args[2], :($)) && isa(ex.args[2].args[1], Symbol)
        # TODO: very silly to special case things this way
        registersymboluse(ex.args[2].args[1], ctx)
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
    if ctx.quoteLvl > 0
        return  # do not lint types in quotes, see issue 166
    end
    if tname != Symbol("")
        if islower(string(tname)[1])
            msg(ctx, :I771, tname, "type names should start with an upper case")
        end
        addtype!(ctx.callstack[end-1], tname)
    end

    fields = Any[]
    funcs = Any[]

    for def in ex.args[3].args
        if isa(def, LineNumberNode)
            ctx.line = def.line-1
        elseif isa(def, Symbol)
            # it means Any, probably not a very efficient choice
            if !pragmaexists("Ignore untyped field $(def)", ctx, deep=false)
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
                !pragmaexists("Ignore dimensionless array field $(def.args[1])", ctx, deep=false)
                msg(ctx, :I692, def.args[1], "array field has no dimension which can be slow")
            end
            push!(fields, (def.args[1], def.args[2]))
        elseif isexpr(def, :(=)) && isexpr(def.args[1], :call) || isexpr(def, :function)
            # curly bracket doesn't belong here. catch it first before linting the rest of the function body
            if def.args[1].head == :tuple
                # if julia supports anonymous constructor syntactic sugar, remove this, and make sure ctx.scope is type name
                msg(ctx, :E417, "anonymous function inside type definition")
            elseif isexpr(def.args[1].args[1], :curly)
                for i in 2:length(def.args[1].args[1].args)
                    fp = def.args[1].args[1].args[i]
                    if isa(fp, Symbol) && in(fp, typeparams)
                        msg(ctx, :E523, fp, "constructor parameter collides with a type parameter")
                    end
                    if isexpr(fp, :(<:)) && in(fp.args[1], typeparams)
                        tmp = fp.args[1]
                        msg(ctx, :E523, tmp, "constructor parameter collides with a type parameter")
                    end
                end
            end
            push!(funcs, (def, ctx.line))
        end
    end

    if tname != Symbol("")
        ctx.callstack[end-1].typefields[tname] = fields
    end

    for f in funcs
        ctx.line = f[2]
        lintfunction(f[1], ctx; ctorType = tname)
    end

    if ctx.macroLvl ==0 && ctx.functionLvl == 0
        popcallstack(ctx)
    end
end

function linttypealias(ex::Expr, ctx::LintContext)
    # TODO: make this just part of lintassignment
    if isa(ex.args[1], Symbol)
        addtype!(ctx.callstack[end], withincurly(ex.args[1]))
    end
end

function lintabstract(ex::Expr, ctx::LintContext)
    if isa(ex.args[1], Symbol)
        addtype!(ctx.callstack[end], ex.args[1])
    elseif isexpr(ex.args[1], :curly)
        addtype!(ctx.callstack[end], ex.args[1].args[1])
    elseif isexpr(ex.args[1], :(<:))
        if isa(ex.args[1].args[1], Symbol)
            addtype!(ctx.callstack[end], ex.args[1].args[1])
        elseif isexpr(ex.args[1].args[1], :curly)
            addtype!(ctx.callstack[end], ex.args[1].args[1].args[1])
        end
    end
end

function lintbitstype(ex::Expr, ctx::LintContext)
    if !isa(ex.args[2], Symbol)
        msg(ctx, :E524, "bitstype needs its 2nd argument to be a new type symbol")
    else
        addtype!(ctx.callstack[end], ex.args[2])
    end
end
