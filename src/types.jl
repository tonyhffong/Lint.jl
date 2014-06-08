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
    s = s * @sprintf( "[%20s] ", m.scope )
    s = s * @sprintf( "%4d ", m.line )
    arr = [ "FYI", "WARN", "ERROR", "FATAL" ]
    s = s * @sprintf( "%-5s ", arr[ m.level+1 ] )
    s = s * m.message
    print( io, s )
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
    messages  :: Array{ Any, 1 }
    LintContext() = new( "none", 0, 1, "", ".",
            Dict{Symbol,Any}(), Dict{Symbol,Any}(), Dict{Symbol,Any}(),
            0,
            0,
            { LintStack() }, {} )
end

