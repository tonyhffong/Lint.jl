# module, using, import, export

function lintmodule(ex::Expr, ctx::LintContext)
    addconst!(ctx.callstack[end], ex.args[2], Module,
              Location(ctx.file, ctx.line))
    pushcallstack(ctx)
    stacktop = ctx.callstack[end]
    stacktop.inModule = true
    stacktop.moduleName = ex.args[2]
    stacktop.isTop = true

    lintexpr(ex.args[3], ctx)

    undefs = setdiff(stacktop.exports, stacktop.macros)
    undefs = setdiff(undefs, keys(stacktop.declglobs))
    undefs = setdiff(undefs, keys(stacktop.localvars[1]))
    undefs = setdiff(undefs, stacktop.imports)

    for sym in undefs
        msg(ctx, :W361, sym, "exporting undefined symbol")
    end
    popcallstack(ctx)
end

function lintusing(ex::Expr, ctx::LintContext)
    # Don't use modules protected by a guard (these can cause crashes!)
    # see issue #149
    ctx.ifdepth > 0 && return
    if ctx.functionLvl > 0
        msg(ctx, :E414, "using is not allowed inside function definitions")
    end
    for s in ex.args
        if s != :(.)
            register_global(
                ctx,
                s,
                VarInfo(Location(ctx.file, ctx.line))
           )
        end
    end
    if ex.args[1] != :(.) && ctx.versionreachable(VERSION)
        m = nothing
        path = join(map(string, ex.args), ".")
        try
            eval(Main, ex)
            m = eval(Main, parse(path))
        end
        t = typeof(m)
        if t == Module
            for n in names(m)
                if !haskey(ctx.callstack[end].declglobs, n)
                    register_global(
                        ctx,
                        n,
                        VarInfo(Location(ctx.file, ctx.line))
                   )
                end
            end

            if in(:lint_helper, names(m, true))
                if !haskey(ctx.callstack[end].linthelpers, path)
                    println("found lint_helper in " * string(m))
                end
                ctx.callstack[end].linthelpers[path] = m.lint_helper
            end
        end
    end
end

function lintexport(ex::Expr, ctx::LintContext)
    if ctx.functionLvl > 0
        msg(ctx, :E415, "export is not allowed inside function definitions")
    end
    for sym in ex.args
        if in(sym, ctx.callstack[end].exports)
            msg(ctx, :E333, sym, "duplicate exports of symbol")
        else
            push!(ctx.callstack[end].exports, sym)
        end
    end
end

function lintimport(ex::Expr, ctx::LintContext; all::Bool = false)
    if ctx.functionLvl > 0
        msg(ctx, :E416, "import is not allowed inside function definitions")
    end
    if !ctx.versionreachable(VERSION)
        return
    end
    problem = false
    m = nothing
    register_global(
        ctx,
        ex.args[end],
        VarInfo(Location(ctx.file, ctx.line))
    )
    push!(ctx.callstack[end].imports, ex.args[end])
end
