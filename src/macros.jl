function lintmacro(ex::Expr, ctx::LintContext)
    if !isa(ex.args[1], Expr) || isempty(ex.args[1].args)
        msg(ctx, :E121, ex.args[1], "Lint does not understand the expression")
        return
    end
    fname = ex.args[1].args[1]
    push!(ctx.callstack[end].macros, Symbol("@" * string(fname)))
    push!(ctx.callstack[end].localarguments, Dict{Symbol, Any}())
    push!(ctx.callstack[end].localusedargs, Set{Symbol}())

    # grab the arguments. push a new stack, populate the new stack's argument fields and process the block
    stacktop = ctx.callstack[end]
    resolveArguments = (sube) -> begin
        if typeof(sube) == Symbol
            stacktop.localarguments[end][sube]=VarInfo(ctx.line)
        #= # I don't think macro arguments use any of these
        elseif sube.head == :parameters
            for kw in sube.args
                resolveArguments(kw)
            end
        elseif sube.head == :(=) || sube.head == :kw
            resolveArguments(sube.args[1])
        elseif sube.head == :(::) && length(sube.args) == 2
            typeex = sube.args[2]
            if  typeex != :Expr && typeex != :Symbol
                msg(ctx, :E522, sube, "macro arguments can only be Symbol/Expr")
            end
            resolveArguments(sube.args[1])
        =#
        elseif sube.head == :(...) || sube.head == :(::)
            resolveArguments(sube.args[1])
        #= # macro definition inside another macro? highly unlikely
        elseif sube.head == :($)
            lintexpr(sube.args[1], ctx)
        =#
        else
            msg(ctx, :E136, sube, "Lint does not understand macro")
        end
    end

    for i = 2:length(ex.args[1].args)
        resolveArguments(ex.args[1].args[i])
    end

    ctx.macroLvl += 1
    lintexpr(ex.args[2], ctx)
    ctx.macroLvl -= 1
    pop!(ctx.callstack[end].localarguments)
    pop!(ctx.callstack[end].localusedargs)
end

istopmacro(ex, mod, mac) = ex in (
    mac,
    GlobalRef(mod, mac),
    Expr(:(.), Symbol(string(mod), mac)))

function lintmacrocall(ex::Expr, ctx::LintContext)
    if istopmacro(ex.args[1], Base, Symbol("@deprecate"))
        return
    end

    if ex.args[1] == Symbol("@lintpragma")
        lintlintpragma(ex, ctx)
        return
    end

    if istopmacro(ex.args[1], Core, Symbol("@doc")) && length(ex.args) >= 2 # see Docile.jl
        if isexpr(ex.args[2], :(->))
            lintexpr(ex.args[2].args[2], ctx) # no need to lint the doc string
            return
        elseif typeof(ex.args[2]) <: AbstractString && length(ex.args) >= 3 && isexpr(ex.args[3], :call)
            # grandfather as a docstring of a previously declared function
            return
        elseif (typeof(ex.args[2]) <: AbstractString ||
              isexpr(ex.args[2], :macrocall) && ex.args[2].args[1] == Symbol("@mstr")
             )
            if length(ex.args) >= 3
                lintexpr(ex.args[3], ctx)
            else
                msg(ctx, :W443, "did you forget an -> after @doc or make it inline?")
            end
            return
        end
        return
    end

    if ex.args[1] == Symbol("@pyimport")
        if length(ex.args) == 2 && typeof(ex.args[2]) == Symbol
            ctx.callstack[end].localvars[end][ex.args[2]] = VarInfo(ctx.line)
        elseif length(ex.args) == 4 && ex.args[3] == :as && typeof(ex.args[4]) == Symbol
            ctx.callstack[end].localvars[end][ex.args[4]] = VarInfo(ctx.line)
        end
        return
    end

    if ex.args[1] == Symbol("@compat")
        # TODO: check number of arguments
        lintexpr(ex.args[2], ctx)
    end

    if ex.args[1] == Symbol("@gensym")
        for i in 2:length(ex.args)
            if typeof(ex.args[i]) == Symbol
                vi = VarInfo(ctx.line)
                ctx.callstack[end].localvars[end][ex.args[i]] = vi
            end
        end
        return
    end

    if ex.args[1] == Symbol("@enum")
        for i in 2:length(ex.args)
            if typeof(ex.args[i]) == Symbol
                vi = VarInfo(ctx.line)
                register_global(ctx, ex.args[i], vi, 1)
            elseif isexpr(ex.args[i], :(=)) && typeof(ex.args[i].args[1]) == Symbol
                vi = VarInfo(ctx.line)
                register_global(ctx, ex.args[i].args[1], vi, 1)
            end
        end
        return
    end

    ctx.macrocallLvl = ctx.macrocallLvl + 1

    # AST for things like
    # @windows ? x : y
    # is very weird. This handles that.
    if length(ex.args) == 3 && ex.args[2] == :(?) && isexpr(ex.args[3], :(:))
        for a in ex.args[3].args
            lintexpr(a, ctx)
        end
    else
        for i = 2:length(ex.args)
            lintexpr(ex.args[i], ctx)
        end
    end
    ctx.macrocallLvl = ctx.macrocallLvl - 1
end
