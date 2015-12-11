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
                    msg(ctx, :ERROR, 535, adt, "you mean {T<:$(adt)}? You are " *
                        "introducing it as a new name for an algebric data type, " *
                        "unrelated to the type $(adt)")
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
                        msg(ctx, :ERROR, 538, temptype, "you should use {T<:...} instead " *
                            "of a known type $(temptype) in parametric data type")
                    end
                end
                if in(typeconstraint, knowntypes)
                    dt = eval(typeconstraint)
                    if typeof(dt) == DataType && isleaftype(dt)
                        msg(ctx, :ERROR, 514, dt, "$(dt) is a leaf type. As a type " *
                            "constraint it makes no sense in $(adt)")
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
            msg(ctx, :INFO, 771, typename, "Julia style recommends type names start with " *
                "an upper case: $(typename)")
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
            if !pragmaexists(utf8("Ignore untyped field $(def)"), ctx, deep=false)
                msg(ctx, :INFO, 691, def, "a type is not given to the field $(def), " *
                    "which can be slow.")
            end
            push!(fields, (def, Any))
        elseif isexpr(def, :macrocall) && def.args[1] == Symbol("@lintpragma")
            lintlintpragma(def, ctx)
        elseif isexpr(def, :call) && def.args[1] == Symbol("lintpragma")
            lintlintpragma(def, ctx)
            msg(ctx, :ERROR, 425, "use @lintpragma macro inside type declaration")
        elseif def.head == :(::)
            if isexpr(def.args[2], :curly) && def.args[2].args[1] == :Array && length(def.args[2].args) <= 2 &&
                !pragmaexists("Ignore dimensionless array field $(def.args[1])", ctx, deep=false)
                msg(ctx, :INFO, 692, def.args[1], "array field $(def.args[1]) has no " *
                    "dimension, which can be slow")
            end
            push!(fields, (def.args[1], def.args[2]))
        elseif def.head == :(=) && isexpr(def.args[1], :call) || def.head == :function
            # curly bracket doesn't belong here. catch it first before linting the rest of the function body
            if def.args[1].head == :tuple
                # if julia supports anonymous constructor syntactic sugar, remove this, and make sure ctx.scope is type name
                msg(ctx, :ERROR, 417, "what is an anonymous function doing inside a type definition?")
            elseif isexpr(def.args[1].args[1], :curly)
                for i in 2:length(def.args[1].args[1].args)
                    fp = def.args[1].args[1].args[i]
                    if typeof(fp) == Symbol && in(fp, typeparams)
                        msg(ctx, :ERROR, 523, fp, "constructor parameter (within curly " *
                            "brackets) $(fp) collides with a type parameter")
                    end
                    if isexpr(fp, :(<:)) && in(fp.args[1], typeparams)
                        tmp = fp.args[1]
                        msg(ctx, :ERROR, 523, fp, "constructor parameter (within curly " *
                            "brackets) $(tmp) collides with a type parameter")
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
        msg(ctx, :ERROR, 524, "bitstype needs its 2nd argument to be a new type symbol")
    else
        push!(ctx.callstack[end].types, ex.args[2])
    end
end
