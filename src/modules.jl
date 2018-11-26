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
    mi = ModuleInfo(name)
    vi = VarInfo(location(ctx), Module)
    info!(vi, mi)

    # set binding in parent module
    set!(ctx.current, name, vi)
    
    # set binding in this module
    mctx = ModuleContext(ctx.current, mi)
    set!(mctx, name, VarInfo(vi))

    withcontext(ctx, mctx) do
        lintexpr(ex.args[3], ctx)
        for sym in exports(ctx.current)
            if lookup(ctx.current, sym) == nothing
                msg(ctx, :W361, sym, "exporting undefined symbol")
            end
        end
    end
    info!(get(lookup(ctx.current, name)), data(mctx))
end

"""
    walkmodulepath(m::Module, path::AbstractVector{Symbol}) :: Union{Any, Nothing}

Walk the module `m` based on the path descripton given by a series of symbols
describing submodules of `m`. For example, if `m === Base` and `path ==
[:Iterators, :take]`, then this returns `Base.Iterators.take`. If an error
occurs at any step, `nothing` is returned.

```jldoctest
julia> using Lint.walkmodulepath

julia> using Compat

julia> walkmodulepath(Compat, [:Iterators, :take])
take (generic function with 2 methods)
```
"""
function walkmodulepath(m::Module, path::AbstractVector{Symbol})::Union{Any, Nothing}
    # walk down m until we get to the requested symbol
    for s in path
        try
            m = getfield(m, s)
        catch
            return nothing
        end
    end
    m
end

function importobject(ctx::LintContext, name::Symbol, obj, source::Symbol)
    # TODO: don't overwrite existing identifiers
    vi = VarInfo(location(ctx), Core.Typeof(obj); source=source)
    info!(vi, StandardLibraryObject(obj))
    set!(ctx.current, name, vi)
end

function importintocontext(m::Module, p::AbstractVector{Symbol},
                           source::Symbol, getexports::Bool, ctx::LintContext)
    # walk down m until we get to the requested symbol
    maybem = walkmodulepath(m, @view(p[2:end]))
    if maybem == nothing
        msg(ctx, :W360, join(string.(p), "."),
            "importing probably undefined symbol")
        return
    end
    m = maybem

    if getexports && isa(m, Module)
        for n in names(m)
            try
                obj = getfield(m, n)
                importobject(ctx, n, obj, source)
            catch
                set!(ctx.current, n, VarInfo(location(ctx); source=source))
            end
        end
    end

    importobject(ctx, p[end], m, source)
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
        if path(imp)[1] in [:Base, :Compat, :Core, :Lint]
            m = getfield(Lint, path(imp)[1])
            importintocontext(m, path(imp), source, getexports, ctx)
        elseif getexports
            # unfortunately, we need to import dynamically
            maybem = dynamic_import_toplevel_module(path(imp)[1])
            if maybem == nothing
                # TODO: make an effort to import the symbol?
                msg(ctx, :W101, path(imp)[1],
                    "unfortunately, Lint could not determine the exports of this module")
                return
            end
            m = maybem
            importintocontext(m, path(imp), source, getexports, ctx)
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
            if result == nothing
                msg(ctx, :W360, join(string.(path(imp)), "."),
                    "importing probably undefined symbol")
                return
            else
                vi = result
                if vi.typeactual <: Module && vi.extra ≠ nothing && isa(vi.extra, ModuleInfo)
                    frommodule = vi.extra
                else
                    canimport = false
                end
            end
        end

        set!(ctx.current, path(imp)[end], VarInfo(vi; source=source))
        
        if getexports && vi.typeactual <: Module && vi.extra ≠ nothing &&
           isa(vi.extra, ModuleInfo)
            for n in vi.extra.exports
                nvi = lookup(vi.extra, n)
                if nvi ≠ nothing
                    set!(ctx.current, n, VarInfo(nvi); source=source)
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
