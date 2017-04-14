immutable Location
    file::String
    line::Int
end
file(loc::Location) = loc.file
line(loc::Location) = loc.line
file(x) = file(location(x))
line(x) = line(location(x))

const UNKNOWN_LOCATION = Location("unknown", -1)

# TODO: Replace with Location(file, line)
type LintMessage
    file    :: String
    code    :: Symbol #[E|W|I][1-9][1-9][1-9]
    scope   :: String
    line    :: Int
    variable:: String
    message :: String
end

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

location(vi::VarInfo) = vi.location
registeruse!(vi::VarInfo) = (vi.usages += 1; vi)
usages(vi::VarInfo) = vi.usages
source(vi::VarInfo) = vi.source

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
atfinish(ctx::_LintContext, _) = nothing

# A special context for linting a `module` keyword
immutable ModuleContext <: _LintContext
    parent        :: Nullable{_LintContext}
    data          :: ModuleInfo
    pragmas       :: Dict{String, PragmaInfo}
    ModuleContext(parent, data) = new(parent, data, Dict())
end

pragmas(mctx::ModuleContext) = mctx.pragmas
parent(mctx::ModuleContext) = get(mctx.parent)
data(mctx::ModuleContext) = mctx.data
lookup(mctx::ModuleContext, args...; kwargs...) =
    lookup(mctx.data, args...; kwargs...)
set!(mctx::ModuleContext, sym::Symbol, info::VarInfo) =
    set!(mctx.data, sym, info)
globalset!(mctx::ModuleContext, sym::Symbol, info::VarInfo) =
    set!(mctx, sym, info)
export!(mctx::ModuleContext, sym::Symbol) = export!(mctx.data, sym)
exports(mctx::ModuleContext) = exports(mctx.data)
istoplevel(mctx::ModuleContext) = true
function atfinish(ctx::ModuleContext, cursor)
    for x in keys(ctx.data.globals)
        vi = ctx.data.globals[x]
        if source(vi) !== :imported  # allow imported bindings
            loc = location(vi)
            if !isnull(stdlibobject(x))
                msg(cursor, :I343, x, "global variable defined at $loc with same name as export from Base")
            end
        end
    end
end

type LocalContext <: _LintContext
    parent        :: _LintContext
    declglobs     :: Set{Symbol}
    localvars     :: Dict{Symbol, VarInfo}
    oosvars       :: Set{Symbol}
    pragmas       :: Dict{String, PragmaInfo}
    LocalContext(parent) = new(parent, Set(), Dict(), Set(), Dict())
end
parent(ctx::LocalContext) = ctx.parent
pragmas(ctx::LocalContext) = ctx.pragmas
function atfinish(ctx::LocalContext, cursor)
    tl = toplevel(ctx)
    for x in keys(ctx.localvars)
        loc = location(ctx.localvars[x])
        if usages(ctx.localvars[x]) == 0 && !startswith(string(x), "_")
            # TODO: a better line number
            msg(cursor, :I340, x, "unused local variable, defined at $loc")
        elseif !isnull(stdlibobject(x))
            msg(cursor, :I342, x, "local variable defined at $loc shadows export from Base")
        elseif !isnull(lookup(tl, x))
            msg(cursor, :I341, x, "local variable defined at $loc shadows global variable defined at $(location(get(lookup(tl, x))))")
        end
    end
end

function set!(s::LocalContext, name::Symbol, vi::VarInfo)
    # TODO: check if symbol already found
    s.localvars[name] = vi
end

function globalset!(s::LocalContext, name::Symbol, vi::VarInfo)
    # TODO: check if this global declaration is legal
    # TODO: remove from localvars if needed
    push!(s.declglobs, name)
    globalset!(parent(s), name, vi)
end

function lookup(ctx::LocalContext, name::Symbol)::Nullable{VarInfo}
    if name in keys(ctx.localvars)
        return ctx.localvars[name]
    elseif name in ctx.declglobs
        return lookup(toplevel(ctx), name)
    else
        return lookup(parent(ctx), name)
    end
end

type LintIgnore
    errorcode::Symbol
    variable::AbstractString
    messages::Array{LintMessage, 1} # messages that have been ignored
    LintIgnore(e::Symbol, v::AbstractString) = new(e, v, LintMessage[])
end

function ==(m1::LintIgnore, m2::LintIgnore)
    m1.errorcode == m2.errorcode &&
    m1.variable == m2.variable
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
location(ctx::LintContext) = Location(ctx.file, ctx.line)
finish(cur::LintContext) = atfinish(cur.current, cur)

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
    atfinish(ctx.current, ctx)
    ctx.current = old
end

function lookup(ctx::LintContext, sym::Symbol)::Nullable{VarInfo}
    lookup(ctx.current, sym)
end
