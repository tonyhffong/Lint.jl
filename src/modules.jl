# module, using, import, export
function lintmodule(ex::Expr, ctx::LintContext)
    @checktoplevel(ctx, "module")

    # TODO: do something about baremodules
    bare = ex.args[1]::Bool
    name = ex.args[2]
    if !isa(name, Symbol)
        msg(ctx, :E100, "module name must be a symbol")
        return
    end
    set!(ctx.current, name, VarInfo(location(ctx), Module))
    mctx = ModuleContext(ctx.current, ModuleInfo(name))
    withcontext(ctx, mctx) do
        lintexpr(ex.args[3], ctx)
        for sym in exports(ctx.current)
            if isnull(lookup(ctx.current, sym))
                msg(ctx, :W361, sym, "exporting undefined symbol")
            end
        end
    end
    info!(get(lookup(ctx.current, name)), data(mctx))
end

function lintusing(ex::Expr, ctx::LintContext)
    @checktoplevel(ctx, "using")

    # Don't use modules protected by a guard (these can cause crashes!)
    # see issue #149
    ctx.ifdepth > 0 && return

    # TODO: distinguish between using and import
    for s in ex.args
        if s != :(.)
            set!(ctx.current, s, VarInfo(location(ctx); source=:imported))
        end
    end
    if ex.args[1] != :(.)
        m = nothing
        path = join(map(string, ex.args), ".")
        # TODO: mark as dynamic
        try
            eval(Main, ex)
            m = eval(Main, parse(path))
        end
        t = typeof(m)
        if t == Module
            for n in names(m)
                # TODO: don't overwrite existing identifiers
                vi = VarInfo(location(ctx), typeof(getfield(m, n));
                             source=:imported)
                set!(ctx.current, n, vi)
            end

            # TODO: restore lint helper
        end
    end
end

function lintexport(ex::Expr, ctx::LintContext)
    @checktoplevel(ctx, "export")
    for sym in ex.args
        if sym in exports(ctx.current)
            msg(ctx, :E333, sym, "duplicate exports of symbol")
        else
            export!(ctx.current, sym)
        end
    end
end

function lintimport(ex::Expr, ctx::LintContext)
    @checktoplevel(ctx, "import")
    set!(ctx.current, ex.args[end], VarInfo(location(ctx); source=:imported))
end
