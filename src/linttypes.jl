include("types/location.jl")
include("types/lintmessage.jl")

# in fact our parent and Base.parent have the same meaning: as if climbing a
# tree toward the root
import Base: parent

@compat abstract type AdditionalVarInfo end

"""
A struct with information about a variable.
"""
type VarInfo
    location::Location
    typeactual::Type

    "The number of times the variable has been used."
    usages::Int

    "The source of the variable. Currently possible values are `:defined` and `:imported`."
    source::Symbol

    "Additional known information about the particular object."
    extra::Nullable{AdditionalVarInfo}

    VarInfo(loc::Location = UNKNOWN_LOCATION, t::Type = Any;
            source::Symbol = :defined) =
        new(loc, t, 0, source, Nullable())
end

VarInfo(vi::VarInfo; source::Symbol = :defined) =
    VarInfo(location(vi), vi.typeactual)

location(vi::VarInfo) = vi.location
registeruse!(vi::VarInfo) = (vi.usages += 1; vi)
usages(vi::VarInfo) = vi.usages
source(vi::VarInfo) = vi.source
function info!(vi::VarInfo, info::AdditionalVarInfo)
    vi.extra = Nullable(info)
end

immutable ModuleInfo <: AdditionalVarInfo
    name          :: Symbol
    globals       :: Dict{Symbol, VarInfo}
    exports       :: Set{Symbol}

    ModuleInfo(name) = new(name, Dict(), Set())
end

name(data::ModuleInfo) = data.name
export!(data::ModuleInfo, sym::Symbol) = push!(data.exports, sym)
exports(data::ModuleInfo) = data.exports
set!(data::ModuleInfo, sym::Symbol, info::VarInfo) = data.globals[sym] = info
function lookup(data::ModuleInfo, sym::Symbol)::Nullable{VarInfo}
    if sym in keys(data.globals)
        return data.globals[sym]
    end

    # check standard library
    val = stdlibobject(sym)
    if !isnull(val)
        return VarInfo(UNKNOWN_LOCATION, Core.Typeof(get(val)))
    end

    return Nullable{VarInfo}()
end

immutable MethodInfo <: AdditionalVarInfo
    # signature :: ...
    location :: Location
    body     :: Any
    isstaged :: Bool
end
location(mi::MethodInfo) = mi.location

# TODO: currently, this is not actually used
immutable FunctionInfo <: AdditionalVarInfo
    name    :: Symbol
    methods :: Vector{MethodInfo}
end
name(data::FunctionInfo) = data.name
method!(data::FunctionInfo, mi::MethodInfo) = push!(data.methods, mi)

type PragmaInfo
    location :: Location
    used     :: Bool
end

@compat abstract type _LintContext end
istoplevel(ctx::_LintContext) = false
toplevel(ctx::_LintContext) = istoplevel(ctx) ? ctx : toplevel(parent(ctx))
pragmas(ctx::_LintContext) = Dict{String, PragmaInfo}()
function pragma!(ctx::_LintContext, pragma, location::Location)
    pragmas(ctx)[pragma] = PragmaInfo(location, false)
end
finish(ctx::_LintContext, _) = nothing
globalset!(ctx::_LintContext, sym::Symbol, info::VarInfo) =
    set!(ctx, sym, info)
localset!(ctx::_LintContext, sym::Symbol, info::VarInfo) =
    set!(ctx, sym, info)

# A special context for linting a `module` keyword
immutable ModuleContext <: _LintContext
    parent        :: Nullable{_LintContext}
    data          :: ModuleInfo
    pragmas       :: Dict{String, PragmaInfo}

    """
    Methods whose linting has been deferred until the completion of this
    context.
    """
    deferred      :: Vector{MethodInfo}

    ModuleContext(parent, data) = new(parent, data, Dict(), [])
end

isroot(mctx::ModuleContext) = isnull(mctx.parent)
pragmas(mctx::ModuleContext) = mctx.pragmas
parent(mctx::ModuleContext) = get(mctx.parent)
data(mctx::ModuleContext) = mctx.data
lookup(mctx::ModuleContext, args...; kwargs...) =
    lookup(mctx.data, args...; kwargs...)
locallookup(mctx::ModuleContext, name::Symbol) = Nullable()
set!(mctx::ModuleContext, sym::Symbol, info::VarInfo) =
    set!(mctx.data, sym, info)
function defer!(mctx::ModuleContext, mi::MethodInfo)
    push!(mctx.deferred, mi)
end
export!(mctx::ModuleContext, sym::Symbol) = export!(mctx.data, sym)
exports(mctx::ModuleContext) = exports(mctx.data)
istoplevel(mctx::ModuleContext) = true
function finish(ctx::ModuleContext, cursor)
    for x in keys(ctx.data.globals)
        vi = ctx.data.globals[x]
        if source(vi) !== :imported  # allow imported bindings
            loc = location(vi)
            if !isnull(stdlibobject(x))
                msg(cursor, :I343, x, "global variable defined at $loc with same name as export from Base")
            end
        end
    end
    for method in ctx.deferred
        lintfunctionbody(cursor, method)
    end
end

type LocalContext <: _LintContext
    parent        :: _LintContext
    declglobs     :: Set{Symbol}
    localvars     :: Dict{Symbol, VarInfo}
    oosvars       :: Set{Symbol}
    pragmas       :: Dict{String, PragmaInfo}

    """
    Methods whose linting has been deferred until the completion of this
    context.
    """
    deferred      :: Vector{MethodInfo}
    LocalContext(parent) = new(parent, Set(), Dict(), Set(), Dict(), [])
end
parent(ctx::LocalContext) = ctx.parent
pragmas(ctx::LocalContext) = ctx.pragmas
function defer!(ctx::LocalContext, mi::MethodInfo)
    push!(ctx.deferred, mi)
end
function finish(ctx::LocalContext, cursor)
    for method in ctx.deferred
        lintfunctionbody(cursor, method)
    end
    tl = toplevel(ctx)
    nl = parent(ctx)
    for x in keys(ctx.localvars)
        loc = location(ctx.localvars[x])
        if usages(ctx.localvars[x]) == 0 && !startswith(string(x), "_")
            # TODO: a better line number
            msg(cursor, :I340, x, "unused local variable, defined at $loc")
        elseif !isnull(stdlibobject(x))
            msg(cursor, :I342, x, "local variable defined at $loc shadows export from Base")
        elseif !isnull(lookup(tl, x))
            msg(cursor, :I341, x, "local variable defined at $loc shadows global variable defined at $(location(get(lookup(tl, x))))")
        elseif !isnull(lookup(nl, x))
            msg(cursor, :I344, x, "local variable defined at $loc shadows local variable defined at $(location(get(lookup(nl, x))))")
        end
    end
end

function set!(s::LocalContext, name::Symbol, vi::VarInfo)
    # TODO: check if it's soft or hard local scope
    var = locallookup(s, name)
    if !isnull(var)
        # TODO: warn about type instability?
        get(var).typeactual = Union{get(var).typeactual, vi.typeactual}
    else
        localset!(s, name, vi)
    end
end

function localset!(s::LocalContext, name::Symbol, vi::VarInfo)
    # TODO: check if already set?
    s.localvars[name] = vi
end

function globalset!(s::LocalContext, name::Symbol, vi::VarInfo)
    # TODO: check if this global declaration is legal
    # TODO: remove from localvars if needed
    push!(s.declglobs, name)
    globalset!(parent(s), name, vi)
end

function locallookup(ctx::LocalContext, name::Symbol)::Nullable{VarInfo}
    if name in keys(ctx.localvars)
        return ctx.localvars[name]
    elseif name in ctx.declglobs
        return lookup(toplevel(ctx), name)
    else
        return locallookup(parent(ctx), name)
    end
end

function lookup(ctx::LocalContext, name::Symbol)::Nullable{VarInfo}
    var = locallookup(ctx, name)
    if isnull(var)
        lookup(toplevel(ctx), name)
    else
        var
    end
end

@auto_hash_equals immutable LintIgnore
    errorcode::Symbol
    variable::AbstractString
    LintIgnore(e::Symbol, v::AbstractString) = new(e, v)
end

const LINT_IGNORE_DEFAULT = LintIgnore[LintIgnore(:W651, "")]

type LintContext
    file         :: String
    line         :: Int
    lineabs      :: Int
    scope        :: String # usually the function name
    path         :: String
    included     :: Array{AbstractString,1} # list of files included
    macrocallLvl :: Int
    quoteLvl     :: Int
    messages     :: Array{LintMessage, 1}
    versionreachable:: Function # VERSION -> true means this code is reachable by VERSION
    ignore       :: Array{LintIgnore, 1}
    ifdepth      :: Int
    current      :: _LintContext
    function LintContext()
        mdata = ModuleInfo(:Main)
        mctx = ModuleContext(Nullable(), mdata)
        new("none", 0, 1, "", ".", AbstractString[],
            0, 0, LintMessage[], _ -> true,
            copy(LINT_IGNORE_DEFAULT), 0, mctx)
    end
end
location(ctx::LintContext) = Location(ctx.file, ctx.line + ctx.lineabs)
function location!(ctx::LintContext, loc::Location)
    ctx.file = file(loc)
    ctx.path = dirname(ctx.file)
    ctx.lineabs = line(loc)
    ctx.line = 0
end

finish(cur::LintContext) = finish(cur.current, cur)

function LintContext(file::AbstractString; ignore::Array{LintIgnore, 1} = LintIgnore[])
    ctx = LintContext()
    append!(ctx.ignore, ignore)
    ctx.file = file
    if ispath(file)
        ctx.path = dirname(abspath(file))
    end
    return ctx
end

function withcontext(f, ctx::LintContext, temp::_LintContext)
    old = ctx.current
    ctx.current = temp
    f()
    finish(ctx.current, ctx)
    ctx.current = old
end

function lookup(ctx::LintContext, sym::Symbol)::Nullable{VarInfo}
    lookup(ctx.current, sym)
end

function msg(ctx::LintContext, code::Symbol, variable, str::AbstractString)
    variable = string(variable)
    m = LintMessage(location(ctx), code, ctx.scope, variable, str)
    # filter out messages to ignore
    i = findfirst(ctx.ignore, LintIgnore(code, variable))
    if i == 0
        push!(ctx.messages, m)
    else
        push!(ctx.ignore[i].messages, m)
    end
end

function msg(ctx::LintContext, code::Symbol, str::AbstractString)
    msg(ctx, code, "", str)
end
