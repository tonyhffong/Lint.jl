include("types/location.jl")
include("types/lintmessage.jl")

# in fact our parent and Base.parent have the same meaning: as if climbing a
# tree toward the root
import Base: parent

function Typeof(@nospecialize x)
    if x === Vararg
        typeof(x)
    elseif isa(x, Type)
        Type{x}
    else
        typeof(x)
    end
end

@compat abstract type AdditionalVarInfo end
extractobject(_::AdditionalVarInfo) = nothing

"""
A struct with information about a variable.
"""
mutable struct VarInfo
    location::Location
    typeactual::Type

    "The number of times the variable has been used."
    usages::Int

    """
    The source of the variable. Currently possible values are `:defined`,
    `:used`, and `:imported`.
    """
    source::Symbol

    "Additional known information about the particular object."
    extra::Union{AdditionalVarInfo, Nothing}

    VarInfo(loc::Location = UNKNOWN_LOCATION, t::Type = Any;
            source::Symbol = :defined) =
        new(loc, t, 0, source, nothing)
end

VarInfo(vi::VarInfo; source::Symbol = :defined) =
    VarInfo(location(vi), vi.typeactual)

location(vi::VarInfo) = vi.location
registeruse!(vi::VarInfo) = (vi.usages += 1; vi)
usages(vi::VarInfo) = vi.usages
source(vi::VarInfo) = vi.source
function info!(vi::VarInfo, info::AdditionalVarInfo)
    vi.extra = info
end

function extractobject(vi::VarInfo)
    if vi.extra !== nothing
        extractobject(vi.extra)
    end
end


struct ModuleInfo <: AdditionalVarInfo
    name          :: Symbol
    globals       :: Dict{Symbol, VarInfo}
    exports       :: Set{Symbol}

    ModuleInfo(name) = new(name, Dict(), Set())
end

name(data::ModuleInfo) = data.name
export!(data::ModuleInfo, sym::Symbol) = push!(data.exports, sym)
exports(data::ModuleInfo) = data.exports
set!(data::ModuleInfo, sym::Symbol, info::VarInfo) = data.globals[sym] = info
function lookup(data::ModuleInfo, sym::Symbol)::Union{VarInfo, Nothing}
    if sym in keys(data.globals)
        return data.globals[sym]
    end

    # check standard library
    val = stdlibobject(sym)
    if val !== nothing
        vi = VarInfo(UNKNOWN_LOCATION, Typeof(val))
        info!(vi, StandardLibraryObject(val))
        return vi
    end

    return nothing
end

struct MethodInfo <: AdditionalVarInfo
    # signature :: ...
    location :: Location
    body     :: Any
    isstaged :: Bool
end
location(mi::MethodInfo) = mi.location

"""
The binding is known to reference a standard library object. The "standard
library" consists of `Core`, `Base`, `Compat`, and their submodules.
"""
struct StandardLibraryObject <: AdditionalVarInfo
    object :: Any
end
# TODO: remove {typeof(x.object)} part when #21397 fixed
extractobject(x::StandardLibraryObject) =
    x.object

# TODO: currently, this is not actually used
struct FunctionInfo <: AdditionalVarInfo
    name    :: Symbol
    methods :: Vector{MethodInfo}
end
name(data::FunctionInfo) = data.name
method!(data::FunctionInfo, mi::MethodInfo) = push!(data.methods, mi)

struct PragmaInfo
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
struct ModuleContext <: _LintContext
    parent        :: Union{_LintContext, Nothing}
    data          :: ModuleInfo
    pragmas       :: Dict{String, PragmaInfo}

    """
    Methods whose linting has been deferred until the completion of this
    context.
    """
    deferred      :: Vector{MethodInfo}

    ModuleContext(parent, data) = new(parent, data, Dict(), [])
end

isroot(mctx::ModuleContext) = mctx.parent ≡ nothing
pragmas(mctx::ModuleContext) = mctx.pragmas
parent(mctx::ModuleContext) = get(mctx.parent)
data(mctx::ModuleContext) = mctx.data
lookup(mctx::ModuleContext, args...; kwargs...) =
    lookup(mctx.data, args...; kwargs...)
locallookup(mctx::ModuleContext, name::Symbol) = nothing
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
        if source(vi) ∉ [:imported, :used]  # allow imported/used bindings
            loc = location(vi)
            if stdlibobject(x) !== nothing
                msg(cursor, :I343, x, "global variable defined at $loc with same name as export from Base")
            end
        end
    end
    for method in ctx.deferred
        lintfunctionbody(cursor, method)
    end
end

struct LocalContext <: _LintContext
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
        elseif stdlibobject(x) !== nothing
            msg(cursor, :I342, x, "local variable defined at $loc shadows export from Base")
        elseif lookup(tl, x) !== nothing
            msg(cursor, :I341, x, "local variable defined at $loc shadows global variable defined at $(location(lookup(tl, x)))")
        elseif lookup(nl, x) !== nothing
            msg(cursor, :I344, x, "local variable defined at $loc shadows local variable defined at $(location(lookup(nl, x)))")
        end
    end
end

function set!(s::LocalContext, name::Symbol, vi::VarInfo)
    # TODO: check if it's soft or hard local scope
    var = locallookup(s, name)
    if var !== nothing
        # TODO: warn about type instability?
        var.typeactual = Union{var.typeactual, vi.typeactual}
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

function locallookup(ctx::LocalContext, name::Symbol)::Union{VarInfo, Nothing}
    if name in keys(ctx.localvars)
        return ctx.localvars[name]
    elseif name in ctx.declglobs
        return lookup(toplevel(ctx), name)
    else
        return locallookup(parent(ctx), name)
    end
end

function lookup(ctx::LocalContext, name::Symbol)::Union{VarInfo, Nothing}
    var = locallookup(ctx, name)
    if var ≡ nothing
        lookup(toplevel(ctx), name)
    else
        var
    end
end

@auto_hash_equals struct LintIgnore
    errorcode :: Symbol
    variable  :: String
end

const LINT_IGNORE_DEFAULT = [
    LintIgnore(:I341, ""),
    LintIgnore(:I342, ""),
    LintIgnore(:W651, "")
]

mutable struct LintContext
    file         :: String
    "Current line number."
    line         :: Int
    "Line number at which the current toplevel expression begins at."
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
        mctx = ModuleContext(nothing, mdata)
        new("none", 0, 1, "", ".", AbstractString[],
            0, 0, LintMessage[], _ -> true,
            copy(LINT_IGNORE_DEFAULT), 0, mctx)
    end
end
location(ctx::LintContext) = Location(ctx.file, ctx.line)
function location!(ctx::LintContext, loc::Location)
    ctx.file = file(loc)
    ctx.path = dirname(ctx.file)
    ctx.line = line(loc)
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

function lookup(ctx::LintContext, sym::Symbol)::Union{VarInfo, Nothing}
    lookup(ctx.current, sym)
end

function msg(ctx::LintContext, code::Symbol, variable, str::AbstractString)
    variable = string(variable)
    m = LintMessage(location(ctx), code, ctx.scope, variable, str)
    # filter out messages to ignore
    if !(LintIgnore(code, variable) in ctx.ignore ||
         LintIgnore(code, "") in ctx.ignore)
        push!(ctx.messages, m)
    end
end

function msg(ctx::LintContext, code::Symbol, str::AbstractString)
    msg(ctx, code, "", str)
end
