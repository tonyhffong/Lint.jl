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

function lintimport(ex::Expr, ctx::LintContext)
    if ctx.quoteLvl > 0
        return  # not safe to import in quotes
    end
    imp = get(understand_import(ex))
    @checktoplevel(ctx, kind(imp))

    # Don't use modules protected by a guard (these can cause crashes!)
    # see issue #149
    ctx.ifdepth > 0 && return

    source = kind(imp) === :using ? :used : :imported
    getexports = kind(imp) !== :import

    if dots(imp) == 0
        # top-level import
        if getexports
            # unfortunately, we need to import dynamically
            maybem = dynamic_import_toplevel_module(path(imp)[1])
            if isnull(maybem)
                # TODO: make an effort to import the symbol?
                msg(ctx, :W101, path(imp)[1],
                    "unfortunately, Lint could not determine the exports of this module")
                return
            end
            m = get(maybem)
            # walk down m until we get to the requested symbol
            for s in @view(path(imp)[2:end])
                try
                    m = getfield(m, s)
                catch
                    msg(ctx, :W360, join(string.(path(imp)), "."),
                        "importing probably undefined symbol")
                    return
                end
            end

            if isa(m, Module)
                for n in names(m)
                    # TODO: don't overwrite existing identifiers
                    typ = try
                        typeof(getfield(m, n))
                    catch
                        Any
                    end
                    vi = VarInfo(location(ctx), typ; source=source)
                    set!(ctx.current, n, vi)
                end
            end
            set!(ctx.current, path(imp)[end],
                 VarInfo(location(ctx), typeof(m); source=source))
        else
            set!(ctx.current, path(imp)[end],
                 VarInfo(location(ctx); source=source))
        end
    else
        importfrom = ctx.current
        for i = 2:dots(imp)
            if isroot(importfrom)
                msg(ctx, :W362, join(string.(path(imp))),
                    "relative import is too deep; at least $(dots(imp) - i) superfluous dots")
                return
            end
            importfrom = parent(importfrom)
        end

        # walk down importfrom until we get to the requested symbol
        frommodule = data(importfrom)
        local vi
        canimport = true
        for s in path(imp)
            if !canimport
                msg(ctx, :W363, join(string.(path(imp)), "."),
                    "attempted import from probable non-module")
                return
            end
            result = lookup(frommodule, s)
            if isnull(result)
                msg(ctx, :W360, join(string.(path(imp)), "."),
                    "importing probably undefined symbol")
                return
            else
                vi = get(result)
                if vi.typeactual <: Module && !isnull(vi.extra) && isa(get(vi.extra), ModuleInfo)
                    frommodule = get(vi.extra)
                else
                    canimport = false
                end
            end
        end

        set!(ctx.current, path(imp)[end], VarInfo(vi; source=source))
        
        if getexports && vi.typeactual <: Module && !isnull(vi.extra) &&
           isa(get(vi.extra), ModuleInfo)
            for n in get(vi.extra).exports
                nvi = lookup(get(vi.extra), n)
                if !isnull(nvi)
                    set!(ctx.current, n, VarInfo(get(nvi); source=source))
                else
                    set!(ctx.current, n, VarInfo(location(ctx); source=source))
                end
            end
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
