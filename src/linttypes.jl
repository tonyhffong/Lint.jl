immutable Location
    file::String
    line::Int
end
file(loc::Location) = loc.file
line(loc::Location) = loc.line

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

type VarInfo
    location::Location
    typeactual::Type
    # We may know that it is Array{T, 1}, though we do not know T, for example
    typeexpr::Union{Expr, Symbol}

    # how many times the variable is used
    usages::Int

    VarInfo() = new(UNKNOWN_LOCATION, Any, :(), 0)
    VarInfo(loc::Location, t::Type = Any) = new(loc, t, :(), 0)
    VarInfo(l::Int) = new(Location("unknown", l), Any, :(), 0)
    VarInfo(l::Int, t::Type) = new(Location("unknown", l), t, :(), 0)
    VarInfo(l::Int, ex::Expr) = new(Location("unknown", l), Any, ex, 0)
    VarInfo(ex::Expr) = new(UNKNOWN_LOCATION, Any, ex, 0)
end
file(vi::VarInfo) = file(vi.location)
line(vi::VarInfo) = line(vi.location)
registeruse!(vi::VarInfo) = (vi.usages += 1; vi)

type PragmaInfo
    line :: Int
    used :: Bool
end

type LintStack
    declglobs     :: Dict{Symbol, VarInfo}
    localarguments:: Array{Dict{Symbol, VarInfo}, 1}
    localvars     :: Array{Dict{Symbol, VarInfo}, 1}
    oosvars       :: Set{Symbol}
    pragmas       :: Dict{String, PragmaInfo} # the boolean denotes if the pragma has been used
    calledfuncs   :: Set{Symbol}
    inModule      :: Bool
    moduleName    :: Any
    typefields    :: Dict{Any, Any}
    exports       :: Set{Any}
    imports       :: Set{Any}
    functions     :: Set{Any}
    macros        :: Set{Any}
    linthelpers   :: Dict{String, Any}
    data          :: Dict{Symbol, Any}
    isTop         :: Bool
    LintStack() = begin
        x = new(
            Dict{Symbol,Any}(),
            [Dict{Symbol, Any}()],
            [Dict{Symbol, Any}()],
            Set{Symbol}(),
            Dict{String, Bool}(), #pragmas
            Set{Symbol}(),
            false,
            Symbol(""),
            Dict{Any,Any}(),
            Set{Any}(),
            Set{Any}(),
            Set{Any}(),
            Set{Any}(),
            Dict{String, Any}(),
            Dict{Symbol, Any}(),
            false,
           )
        x
    end
end

function addtype!(s::LintStack, t::Symbol, loc::Location=UNKNOWN_LOCATION)
    s.declglobs[t] = VarInfo(loc, Type)
end

function LintStack(t::Bool)
    x = LintStack()
    x.isTop = t
    x
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
    isstaged     :: Bool
    path         :: String
    included     :: Array{AbstractString,1} # list of files included
    globals      :: Dict{Symbol,Any}
    functions    :: Dict{Symbol,Any}
    functionLvl  :: Int
    macroLvl     :: Int
    macrocallLvl :: Int
    quoteLvl     :: Int
    callstack    :: Array{Any, 1}
    messages     :: Array{LintMessage, 1}
    versionreachable:: Function # VERSION -> true means this code is reachable by VERSION
    ignore       :: Array{LintIgnore, 1}
    ifdepth      :: Int
    LintContext() = new("none", 0, 1, "", false, ".", AbstractString[],
            Dict{Symbol,Any}(), Dict{Symbol,Any}(), 0, 0, 0,
            0, Any[LintStack(true)], LintMessage[], _ -> true,
            copy(LINT_IGNORE_DEFAULT), 0)
end
location(ctx::LintContext) = Location(ctx.file, ctx.line)

function LintContext(file::AbstractString; ignore::Array{LintIgnore, 1} = LintIgnore[])
    ctx = LintContext()
    append!(ctx.ignore, ignore)
    ctx.file = file
    if ispath(file)
        ctx.path = dirname(abspath(file))
    end
    return ctx
end

function pushcallstack(ctx::LintContext)
    push!(ctx.callstack, LintStack())
end

function popcallstack(ctx::LintContext)
    stacktop = ctx.callstack[end]
    for (p,b) in stacktop.pragmas
        if !b.used
            tmpline = ctx.line
            ctx.line = b.line
            msg(ctx, :I381, p, "unused lintpragma")
            ctx.line = tmpline
        end
    end
    pop!(ctx.callstack)
end

function register_global(ctx::LintContext, glob, info::VarInfo,
                         callstackindex=length(ctx.callstack))
    ctx.callstack[callstackindex].declglobs[glob] = info
    filter!(message -> begin
                return !(message.code == :E321 && message.variable == string(glob) &&
                        (!isempty(message.scope) || message.file != ctx.file))
            end,
        ctx.messages
    )
end

function lookup(ctx::LintContext, sym::Symbol;
                register=false)::Nullable{VarInfo}
    use!(x) = register ? registeruse!(x) : x
    stacktop = ctx.callstack[end]

    for varframe in @view(stacktop.localvars[end:-1:1])
        if sym in keys(varframe)
            return use!(varframe[sym])
        end
    end
    for argframe in @view(stacktop.localarguments[end:-1:1])
        if sym in keys(argframe)
            return use!(argframe[sym])
        end
    end
    for stackframe in @view(ctx.callstack[end:-1:1])
        if sym in stackframe.functions
            return VarInfo(-1, Function)
        elseif sym in stackframe.imports
            return VarInfo(-1, Any)
        elseif sym in keys(stackframe.declglobs)
            return stackframe.declglobs[sym]
        end
    end

    # check standard library
    val = stdlibobject(sym)
    if !isnull(val)
        if isa(get(val), Type)
            return VarInfo(-1, Type{get(val)})
        else
            return VarInfo(-1, typeof(get(val)))
        end
    end
    return Nullable{VarInfo}()
end
