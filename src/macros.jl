function lintmacro(ex::Expr, ctx::LintContext)
    @checktoplevel(ctx, "macro")

    if !isexpr(ex.args[1], :call)
        msg(ctx, :W100, ex.args[1], "this macro syntax not understood by Lint.jl")
        return
    end

    fname = ex.args[1].args[1]
    if !isa(fname, Symbol)
        msg(ctx, :E141, ex.args[1].args[1], "invalid macro syntax")
        return
    end

    # now we pretend we're a function...
    # TODO: make this less hackish
    fname = Symbol('@', fname)
    lintfunction(Expr(:function, Expr(:call, fname, ex.args[1].args[2:end]...),
                      ex.args[2:end]...), ctx)
end

istopmacro(ex, mod, mac) = ex in (
    mac,
    GlobalRef(mod, mac),
    Expr(:(.), Symbol(string(mod)), mac))

function lintcompat(ex::Expr, ctx::LintContext)
    if VERSION < v"0.6.0-dev.2746" &&
       length(ex.args) == 2 && isexpr(ex.args[2], :abstract) &&
       length(ex.args[2].args) == 1 && isexpr(ex.args[2].args[1], :type)
        lintexpr(Compat._compat_abstract(ex.args[2].args[1]), ctx)
    elseif VERSION < v"0.6.0-dev.2746" &&
           length(ex.args) == 3 && ex.args[2] == :primitive
        lintexpr(Compat._compat_primitive(ex.args[3]), ctx)
    elseif length(ex.args) == 2
        lintexpr(Compat._compat(ex.args[2]), ctx)
    else
        msg(ctx, :E437, ex, "@compat called with wrong number of arguments")
    end
end

function lintmacrocall(ex::Expr, ctx::LintContext)
    if istopmacro(ex.args[1], Base, Symbol("@deprecate")) ||
       ex.args[1] == Symbol("@recipe")
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
            set!(ctx.current, ex.args[2], VarInfo(location(ctx)))
        elseif length(ex.args) == 4 && ex.args[3] == :as && typeof(ex.args[4]) == Symbol
            set!(ctx.current, ex.args[4], VarInfo(location(ctx)))
        end
        return
    end

    if istopmacro(ex.args[1], Compat, Symbol("@compat"))
        lintcompat(ex, ctx)
        return
    end

    if ex.args[1] == Symbol("@gensym")
        for i in 2:length(ex.args)
            if typeof(ex.args[i]) == Symbol
                set!(ctx.current, ex.args[i], VarInfo(location(ctx)))
            end
        end
        return
    end

    if ex.args[1] == Symbol("@enum")
        @checktoplevel(ctx, "@enum")
        for i in 2:length(ex.args)
            if typeof(ex.args[i]) == Symbol
                vi = VarInfo(location(ctx))
                set!(ctx.current, ex.args[i], vi)
            elseif isexpr(ex.args[i], :(=)) && typeof(ex.args[i].args[1]) == Symbol
                vi = VarInfo(location(ctx))
                set!(ctx.current, ex.args[i].args[1], vi)
            end
        end
        return
    end

    ctx.macrocallLvl = ctx.macrocallLvl + 1
    for i = 2:length(ex.args)
        lintexpr(ex.args[i], ctx)
    end
    ctx.macrocallLvl = ctx.macrocallLvl - 1
end
