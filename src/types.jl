type LintMessage
    file    :: String
    scope   :: String
    line    :: Int
    level   :: Int # 0: FYI, 1: WARNING, 2: ERROR, 3:FATAL (probably dangerous)
    message :: String
end

import Base.show
function Base.show( io::IO, m::LintMessage )
    s = @sprintf( "%20s ", m.file )
    s = s * @sprintf( "[%-20s] ", m.scope )
    s = s * @sprintf( "%4d ", m.line )
    arr = [ "FYI", "WARN", "ERROR", "FATAL" ]
    s = s * @sprintf( "%-5s  ", arr[ m.level+1 ] )
    ident = length(s)
    lines = split(m.message, "\n")
    for (i,l) in enumerate(lines)
        if i==1
            s = s * l
        else
            s = s * "\n" *  (" " ^ ident) * l
        end
    end
    print( io, s )
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
    m2.message == m2.message
end

type LintStack
    declglobs     :: Set{Symbol}
    localarguments:: Array{ Dict{Symbol, Any}, 1 }
    localvars     :: Array{ Dict{Symbol, Any}, 1 }
    localusedvars :: Array{ Set{Symbol}, 1 }
    usedvars      :: Set{Symbol}
    oosvars       :: Set{Symbol}
    pragmas       :: Set{Symbol}
    inModule      :: Bool
    moduleName    :: Any
    types         :: Set{Any}
    exports       :: Set{Any}
    imports       :: Set{Any}
    functions     :: Set{Any}
    modules       :: Set{Any}
    macros        :: Set{Any}
    linthelpers   :: Dict{ String, Any }
    data          :: Dict{ Symbol, Any }
    isTop         :: Bool
    LintStack() = begin
        x = new(
            Set{Symbol}(),
            [ Dict{Symbol, Any}() ],
            [ Dict{Symbol, Any}() ],
            [ Set{Symbol}() ],
            Set{Symbol}(),
            Set{Symbol}(),
            Set{Symbol}(),
            false,
            symbol(""),
            Set{Any}(),
            Set{Any}(),
            Set{Any}(),
            Set{Any}(),
            Set{Any}(),
            Set{Any}(),
            Dict{ String, Any }(),
            Dict{ Symbol, Any }(),
            false,
            )
        x
    end
end

type LintContext
    file      :: String
    line      :: Int
    lineabs   :: Int
    scope     :: String
    path      :: String
    globals   :: Dict{Symbol,Any}
    types     :: Dict{Symbol,Any}
    functions :: Dict{Symbol,Any}
    functionLvl:: Int
    macrocallLvl  :: Int
    callstack :: Array{ Any, 1 }
    messages  :: Array{ LintMessage, 1 }
    LintContext() = new( "none", 0, 1, "", ".",
            Dict{Symbol,Any}(), Dict{Symbol,Any}(), Dict{Symbol,Any}(),
            0,
            0,
            { LintStack() }, LintMessage[] )
end

