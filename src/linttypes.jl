type LintMessage
    file    :: UTF8String
    scope   :: UTF8String
    line    :: Int
    level   :: Int # 0: INFO, 1: WARNING, 2: ERROR, 3:FATAL (probably dangerous)
    message :: UTF8String
end

import Base.string
function string( m::LintMessage )
    s = @sprintf( "%s:%d ", m.file, m.line )
    s = s * @sprintf( "[%-15s] ", m.scope )
    arr = [ "INFO", "WARN", "ERROR", "FATAL" ]
    s = s * @sprintf( "%-5s  ", arr[ m.level+1 ] )
    ident = min( 60, length(s) )
    lines = split(m.message, "\n")
    for (i,l) in enumerate(lines)
        if i==1
            s = s * l
        else
            s = s * "\n" *  (" " ^ ident) * l
        end
    end
    return s
end

import Base.show
function Base.show( io::IO, m::LintMessage )
    print( io, string(m) )
end

import Base.isless
function Base.isless( m1::LintMessage, m2::LintMessage )
    if m1.file != m2.file
        return isless(m1.file, m2.file)
    end
    if m1.level != m2.level
        return m2.level < m1.level # reverse
    end
    if m1.line != m2.line
        return m1.line < m2.line
    end
    return m1.message < m2.message
end

function ==( m1::LintMessage, m2::LintMessage )
    m1.file == m2.file &&
    m1.level == m2.level &&
    m1.scope == m2.scope &&
    m1.line == m2.line &&
    m1.message == m2.message
end

type VarInfo
    line::Int
    typeactual::Any # most of the time it's DataType, but could be Tuple of types, too
    typeexpr::Union{ Expr, Symbol } # We may know that it is Array{ T, 1 }, though we do not know T, for example
    VarInfo() = new( -1, Any, :() )
    VarInfo( l::Int ) = new( l, Any, :() )
    VarInfo( l::Int, t::DataType ) = new( l, t, :() )
    VarInfo( l::Int, ex::Expr ) = new( l, Any, ex )
    VarInfo( ex::Expr ) = new( -1, Any, ex )
end

type PragmaInfo
    line :: Int
    used :: Bool
end

type LintStack
    declglobs     :: Dict{Symbol, Any}
    localarguments:: Array{ Dict{Symbol, Any}, 1 }
    localusedargs :: Array{ Set{Symbol}, 1 }
    localvars     :: Array{ Dict{Symbol, Any}, 1 }
    localusedvars :: Array{ Set{Symbol}, 1 }
    usedvars      :: Set{Symbol}
    oosvars       :: Set{Symbol}
    pragmas       :: Dict{UTF8String, PragmaInfo } # the boolean denotes if the pragma has been used
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
    linthelpers   :: Dict{ UTF8String, Any }
    data          :: Dict{ Symbol, Any }
    isTop         :: Bool
    LintStack() = begin
        x = new(
            Dict{Symbol,Any}(),
            [ Dict{Symbol, Any}() ],
            [ Set{Symbol}() ],
            [ Dict{Symbol, Any}() ],
            [ Set{Symbol}() ],
            Set{Symbol}(),
            Set{Symbol}(),
            Dict{UTF8String, Bool}(), #pragmas
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
            Dict{ UTF8String, Any }(),
            Dict{ Symbol, Any }(),
            false,
            )
        x
    end
end

function LintStack( t::Bool )
    x = LintStack()
    x.isTop = t
    x
end

type LintIgnoreState
    ignoreUnused::Set{Symbol}
    ignoreUndeclared::Set{Symbol}
    ignore::Dict{Symbol, Bool}
end

function LintIgnoreState()
    x = LintIgnoreState( Set{Symbol}(), Set{Symbol}(), Dict{Symbol,Bool}() )
    x.ignore[ :similarity ] = true
    x
end

type LintContext
    file         :: UTF8String
    line         :: Int
    lineabs      :: Int
    scope        :: UTF8String # usually the function name
    isstaged     :: Bool
    path         :: UTF8String
    globals      :: Dict{Symbol,Any}
    types        :: Dict{Symbol,Any}
    functions    :: Dict{Symbol,Any}
    functionLvl  :: Int
    macroLvl     :: Int
    macrocallLvl :: Int
    quoteLvl     :: Int
    callstack    :: Array{ Any, 1 }
    messages     :: Array{ LintMessage, 1 }
    versionreachable:: Function # VERSION -> true means this code is reachable by VERSION
    ignoreState  :: LintIgnoreState
    LintContext() = new( "none", 0, 1, "", false, ".",
            Dict{Symbol,Any}(), Dict{Symbol,Any}(), Dict{Symbol,Any}(), 0, 0, 0, 0,
            Any[ LintStack( true ) ], LintMessage[], _ -> true, LintIgnoreState() )
end

function LintContext(file::AbstractString)
    ctx = LintContext()
    ctx.file = file
    if ispath(file)
        ctx.path = dirname(file)
    end
    return ctx
end

function pushcallstack( ctx::LintContext )
    push!( ctx.callstack, LintStack() )
end

function popcallstack( ctx::LintContext )
    stacktop = ctx.callstack[end]
    for (p,b) in stacktop.pragmas
        if !b.used
            tmpline = ctx.line
            ctx.line = b.line
            msg( ctx, 0, "Unused @lintpragma " * p )
            ctx.line = tmpline
        end
    end
    pop!( ctx.callstack )
end
