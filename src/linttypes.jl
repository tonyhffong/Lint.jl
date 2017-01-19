type LintMessage
    file    :: Compat.UTF8String
    code    :: Symbol #[E|W|I][1-9][1-9][1-9]
    scope   :: Compat.UTF8String
    line    :: Int
    variable:: Compat.UTF8String
    message :: Compat.UTF8String
end

type VarInfo
    line::Int
    typeactual::Any # most of the time it's DataType, but could be Tuple of types, too
    typeexpr::Union{Expr, Symbol} # We may know that it is Array{T, 1}, though we do not know T, for example
    VarInfo() = new(-1, Any, :())
    VarInfo(l::Int) = new(l, Any, :())
    VarInfo(l::Int, t::DataType) = new(l, t, :())
    VarInfo(l::Int, ex::Expr) = new(l, Any, ex)
    VarInfo(ex::Expr) = new(-1, Any, ex)
end

type PragmaInfo
    line :: Int
    used :: Bool
end

type LintStack
    declglobs     :: Dict{Symbol, Any}
    localarguments:: Array{Dict{Symbol, Any}, 1}
    localusedargs :: Array{Set{Symbol}, 1}
    localvars     :: Array{Dict{Symbol, Any}, 1}
    localusedvars :: Array{Set{Symbol}, 1}
    usedvars      :: Set{Symbol}
    oosvars       :: Set{Symbol}
    pragmas       :: Dict{Compat.UTF8String, PragmaInfo} # the boolean denotes if the pragma has been used
    calledfuncs   :: Set{Symbol}
    inModule      :: Bool
    moduleName    :: Any
    types         :: Set{Any}
    typefields    :: Dict{Any, Any}
    exports       :: Set{Any}
    imports       :: Set{Any}
    functions     :: Set{Any}
    modules       :: Set{Any}
    macros        :: Set{Any}
    linthelpers   :: Dict{Compat.UTF8String, Any}
    data          :: Dict{Symbol, Any}
    isTop         :: Bool
    LintStack() = begin
        x = new(
            Dict{Symbol,Any}(),
            [Dict{Symbol, Any}()],
            [Set{Symbol}()],
            [Dict{Symbol, Any}()],
            [Set{Symbol}()],
            Set{Symbol}(),
            Set{Symbol}(),
            Dict{Compat.UTF8String, Bool}(), #pragmas
            Set{Symbol}(),
            false,
            Symbol(""),
            Set{Any}(),
            Dict{Any,Any}(),
            Set{Any}(),
            Set{Any}(),
            Set{Any}(),
            Set{Any}(),
            Set{Any}(),
            Dict{Compat.UTF8String, Any}(),
            Dict{Symbol, Any}(),
            false,
           )
        x
    end
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
    file         :: Compat.UTF8String
    line         :: Int
    lineabs      :: Int
    scope        :: Compat.UTF8String # usually the function name
    isstaged     :: Bool
    path         :: Compat.UTF8String
    included     :: Array{AbstractString,1} # list of files included
    globals      :: Dict{Symbol,Any}
    types        :: Dict{Symbol,Any}
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
            Dict{Symbol,Any}(), Dict{Symbol,Any}(), Dict{Symbol,Any}(), 0, 0, 0,
            0, Any[LintStack(true)], LintMessage[], _ -> true,
            copy(LINT_IGNORE_DEFAULT), 0)
end

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

function register_global(ctx::LintContext, glob, info, callstackindex=length(ctx.callstack))
    ctx.callstack[callstackindex].declglobs[glob] = info
    filter!(message -> begin
                return !(message.code == :E321 && message.variable == string(glob) &&
                        (!isempty(message.scope) || message.file != ctx.file))
            end,
        ctx.messages
    )
end
