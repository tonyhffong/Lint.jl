# type definition lint code

function linttype(ex::Expr, ctx::LintContext)
    if ctx.macroLvl ==0 && ctx.functionLvl == 0
        pushcallstack(ctx)
    end
    typeparams = Symbol[]

    processCurly = (sube)->begin
        for i in 2:length(sube.args)
            adt= sube.args[i]
            if typeof(adt)== Symbol
                typefound = in(adt, knowntypes)
                if !typefound
                    for j in 1:length(ctx.callstack)
                        if in(adt, ctx.callstack[j].types)
                            typefound = true
                            break
                        end
                    end
                end
                if typefound && adt != :T
                    msg(ctx, :E535, adt, "introducing a new name for an algebric data " *
                        "type, use {T<:$(adt)}")
                end
                push!(ctx.callstack[end].types, adt)
                push!(typeparams, adt)
            elseif isexpr(adt, :(<:))
                temptype = adt.args[1]
                typeconstraint = adt.args[2]

                if temptype != :T
                    typefound = in(temptype, knowntypes)
                    if !typefound
                        for j in 1:length(ctx.callstack)
                            if in(temptype, ctx.callstack[j].types)
                                typefound = true
                                break
                            end
                        end
                    end
                    if typefound
                        msg(ctx, :E538, temptype, "known type in parametric data type, " *
                            "use {T<:...}")
                    end
                end
                if in(typeconstraint, knowntypes)
                    dt = eval(typeconstraint)
                    if isa(dt, Type) && isleaftype(dt)
                        msg(ctx, :E513, adt, "leaf type as a type constraint makes no sense")
                    end
                end
                push!(ctx.callstack[end].types, temptype)
                push!(typeparams, temptype)
            end
        end
    end

    typename = Symbol("")
    if typeof(ex.args[2]) == Symbol
        typename = ex.args[2]
    elseif isexpr(ex.args[2], :($)) && typeof(ex.args[2].args[1]) == Symbol
        registersymboluse(ex.args[2].args[1], ctx)
    elseif isexpr(ex.args[2], :curly)
        typename = ex.args[2].args[1]
        processCurly(ex.args[2])
    elseif isexpr(ex.args[2], :(<:))
        if typeof(ex.args[2].args[1]) == Symbol
            typename = ex.args[2].args[1]
        elseif isexpr(ex.args[2].args[1], :curly)
            typename = ex.args[2].args[1].args[1]
            processCurly(ex.args[2].args[1])
        end
    end
    if typename != Symbol("")
        if islower(string(typename)[1])
            msg(ctx, :I771, typename, "type names should start with an upper case")
        end
        push!(ctx.callstack[end-1].types, typename)
    end

    fields = Any[]
    funcs = Any[]

    for def in ex.args[3].args
        if typeof(def) == LineNumberNode
            ctx.line = def.line-1
        elseif typeof(def) == Symbol
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
        elseif def.head == :(::)
            if isexpr(def.args[2], :curly) && def.args[2].args[1] == :Array && length(def.args[2].args) <= 2 &&
                !pragmaexists("Ignore dimensionless array field $(def.args[1])", ctx, deep=false)
                msg(ctx, :I692, def.args[1], "array field has no dimension which can be slow")
            end
            push!(fields, (def.args[1], def.args[2]))
        elseif def.head == :(=) && isexpr(def.args[1], :call) || def.head == :function
            # curly bracket doesn't belong here. catch it first before linting the rest of the function body
            if def.args[1].head == :tuple
                # if julia supports anonymous constructor syntactic sugar, remove this, and make sure ctx.scope is type name
                msg(ctx, :E417, "anonymous function inside type definition")
            elseif isexpr(def.args[1].args[1], :curly)
                for i in 2:length(def.args[1].args[1].args)
                    fp = def.args[1].args[1].args[i]
                    if typeof(fp) == Symbol && in(fp, typeparams)
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

    if typename != Symbol("")
        ctx.callstack[end-1].typefields[typename] = fields
    end

    for f in funcs
        ctx.line = f[2]
        lintfunction(f[1], ctx; ctorType = typename)
    end

    if ctx.macroLvl ==0 && ctx.functionLvl == 0
        popcallstack(ctx)
    end
end

function linttypealias(ex::Expr, ctx::LintContext)
    if typeof(ex.args[1])== Symbol
        push!(ctx.callstack[end].types, ex.args[1])
    elseif isexpr(ex.args[1], :curly)
        push!(ctx.callstack[end].types, ex.args[1].args[1])
    end
end

function lintabstract(ex::Expr, ctx::LintContext)
    if typeof(ex.args[1]) == Symbol
        push!(ctx.callstack[end].types, ex.args[1])
    elseif isexpr(ex.args[1], :curly)
        push!(ctx.callstack[end].types, ex.args[1].args[1])
    elseif isexpr(ex.args[1], :(<:))
        if typeof(ex.args[1].args[1]) == Symbol
            push!(ctx.callstack[end].types, ex.args[1].args[1])
        elseif isexpr(ex.args[1].args[1], :curly)
            push!(ctx.callstack[end].types, ex.args[1].args[1].args[1])
        end
    end
end

function lintbitstype(ex::Expr, ctx::LintContext)
    if typeof(ex.args[2]) != Symbol
        msg(ctx, :E524, "bitstype needs its 2nd argument to be a new type symbol")
    else
        push!(ctx.callstack[end].types, ex.args[2])
    end
end
