# module, using, import, export

function lintmodule(ex::Expr, ctx::LintContext)
    push!(ctx.callstack[end].modules, ex.args[2])
    pushcallstack(ctx)
    stacktop = ctx.callstack[end]
    stacktop.inModule = true
    stacktop.moduleName = ex.args[2]
    stacktop.isTop = true

    lintexpr(ex.args[3], ctx)

    undefs = setdiff(stacktop.exports, stacktop.types)
    undefs = setdiff(undefs, stacktop.functions)
    undefs = setdiff(undefs, stacktop.macros)
    undefs = setdiff(undefs, keys(stacktop.declglobs))
    undefs = setdiff(undefs, keys(stacktop.localvars[1]))
    undefs = setdiff(undefs, stacktop.imports)

    for sym in undefs
        msg(ctx, :E322, sym, "exporting undefined symbol $(sym)")
    end
    popcallstack(ctx)
end

function lintusing(ex::Expr, ctx::LintContext)
    if ctx.functionLvl > 0
        msg(ctx, :E414, "using is not allowed inside function definitions")
    end
    for s in ex.args
        if s != :(.)
            register_global(
                ctx,
                s,
                @compat(Dict{Symbol,Any}(:file => ctx.file, :line => ctx.line))
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
                        @compat(Dict{Symbol,Any}(:file => ctx.file, :line => ctx.line))
                   )
                end
            end

            if in(:lint_helper, names(m, true))
                if !haskey(ctx.callstack[end].linthelpers, path)
                    println("found lint_helper in " * string(m))
                end
                ctx.callstack[end].linthelpers[path] = m.lint_helper
            end
        else
            if !pragmaexists("Ignore undefined module $(path)", ctx)
                msg(ctx, :W541, path, "$(path) doesn't eval into a Module")
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
            msg(ctx, :E333, sym, "duplicate exports of symbol $(sym)")
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
    lastpart = nothing
    try
        if ex.args[1] == :(.)
            path = string(ctx.callstack[end-1].moduleName)
            for i in 2:length(ex.args)
                path = path * "." * string(ex.args[i])
            end
            m = eval(Main, parse(path))
            lastpart = ex.args[end]
        else
            register_global(
                ctx,
                ex.args[1],
                @compat(Dict{Symbol,Any}(:file => ctx.file, :line => ctx.line))
            )
            eval(Main, ex)
            lastpart = ex.args[end]
            m = eval(Main, parse(join(ex.args, ".")))
        end
    catch er
        problem = true
        println(er)
        println(ex)
    end
    if !problem
        t = typeof(m)
        if t == Module
            union!(ctx.callstack[end].imports, names(m, all))
        elseif typeof(lastpart) == Symbol
            push!(ctx.callstack[end].imports, lastpart)
            #push!(ctx.callstack[end].declglobs, lastport)
        end
    end
end

