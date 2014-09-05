# all usage of deprecated functions are warning
# all method extensions of deprecated generic functions are errors

type DeprecateInfo
    funcname::Any
    sig::Union( Nothing, Array{Any,1} )
    message::UTF8String
    line::Int
end
deprecates = Dict{ Symbol, Vector{ DeprecateInfo } }()

function initDeprecateInfo()
    str = open( readall, Base.find_source_file( "deprecated.jl" ) )

    if VERSION < v"0.4-"
        linecharc = cumsum( map( x->length(x)+1, split( str, "\n", true ) ) )
    else
        linecharc = cumsum( map( x->length(x)+1, split( str, "\n", keep=true ) ) )
    end

    i = start( str )
    lineabs = 1
    while !done( str,i )
        problem = false
        ex = nothing
        lineabs = searchsorted( linecharc, i ).start
        try
            (ex, i ) = parse( str, i )
        catch
            problem = true
        end
        if !problem
            parseDeprecate( ex, lineabs )
        else
            break
        end
    end
end

# to replace node getter's convenient (easy to remember) macro to actual macro
function argReplace!( e::Expr, pattern, replace )
    for j=1:length(e.args)
        if e.args[j] == pattern
            e.args[j] = replace
        elseif typeof(e.args[j]) == Expr
            argReplace!( e.args[j], pattern, replace)
        end
    end
end

function processOneSig( s, typeHints )
    determineType = (tex) -> begin
        if typeof( tex ) == Expr
            tmp = deepcopy( tex )
            for (k,v) in typeHints
                argReplace!( tmp, k, v )
            end
            return tmp
        end

        return tex
    end

    if typeof( s ) == Symbol
        return ( :normal, :Any )
    elseif Meta.isexpr( s, [ :(...),:kw ] ) && typeof( s.args[1] )==Symbol
        return (s.head, :Any )
    elseif Meta.isexpr( s, :(::) )
        ditype = determineType( s.args[end] )
        return (:normal, ditype )
    elseif Meta.isexpr( s, [ :(...), :kw ] ) && Meta.isexpr(s.args[1], :(::) )
        ditype = determineType( s.args[1].args[end] )
        return ( s.head, ditype )
    else
        println( "Lint doesn't understand " * string( s ) * " as an argument." )
    end
end

function parseDeprecate( ex, lineabs )
    global deprecates
    typeHints = Dict{ Symbol, Any }()

    if Meta.isexpr( ex, :function ) || Meta.isexpr( ex, :(=) ) && Meta.isexpr( ex.args[1], :call )
        callex = ex.args[1]
        (funcname, sig) = getFuncNameAndSig( callex )
        if in( funcname, [ :depwarn, :firstcaller ] ) || contains( lowercase( string( funcname ) ), "deprecate" )
            # the first two are support functions.
            # Any function declaration that has "deprecate" in the name...
            # well, the user/developer should know what they are in for.
            return
        end
        if sig == nothing
            return
        end
        if Meta.isexpr( ex.args[2], :block )
            blockcontents = filter( x->typeof(x)==Expr && x.head != :line, ex.args[2].args )
            if isempty( blockcontents ) || blockcontents[1].head != :call || blockcontents[1].args[1] != :depwarn
                # most likely it's either
                # error. The function already blows up. So why bother with Lint?
                # if the first statement isn't depwarn also no-op
                return
            end
            if !haskey( deprecates, funcname )
                deprecates[ funcname ] =  DeprecateInfo[]
            end
            msg = blockcontents[1].args[2]
            push!( deprecates[ funcname ], DeprecateInfo( funcname, sig, msg, lineabs ) )
        end
    elseif Meta.isexpr( ex, :macrocall ) && ex.args[1] == symbol("@deprecate")
        if typeof( ex.args[2] ) == Symbol
            @assert typeof( ex.args[3] ) == Symbol
            funcname = ex.args[2]
            sig = nothing
            msg = string( ex.args[2], " is deprecated. Use ", ex.args[3], " instead." )
            if !haskey( deprecates, funcname )
                deprecates[ funcname ] =  DeprecateInfo[]
            end
            push!( deprecates[ funcname ], DeprecateInfo( funcname, sig, msg, lineabs ) )
        elseif Meta.isexpr( ex.args[2], :call )
            old = ex.args[2]
            (funcname, sig) = getFuncNameAndSig( old )
            new = ex.args[3]
            oldcall = sprint(io->Base.show_unquoted(io,old))
            newcall = sprint(io->Base.show_unquoted(io,new))

            if contains( string( funcname ), "deprecate" )
                return
            end
            if sig == nothing
                return
            end
            if !haskey( deprecates, funcname )
                deprecates[ funcname ] =  DeprecateInfo[]
            end
            msg = string( oldcall, " is deprecated. Use ", newcall, " instead." )
            push!( deprecates[ funcname ], DeprecateInfo( funcname, sig, msg, lineabs ) )
        end
    end
end

function getFuncNameAndSig( callex::Expr, strict::Bool=true )
    typeHints = Dict{ Symbol, Any }()
    if typeof( callex.args[1] )==Symbol || Meta.isexpr( callex.args[1], :(.) )
        funcname = callex.args[1]
    elseif Meta.isexpr( callex.args[1], :curly )
        funcname = callex.args[1].args[1]
        for i in 2:length( callex.args[1].args )
            tconstr= callex.args[1].args[i]
            if typeof( tconstr ) == Symbol && length( string( tconstr ) )==1
                typeHints[ tconstr ] = Any
            elseif Meta.isexpr( tconstr, :(<:) )
                typeHints[ tconstr.args[1] ] = tconstr.args[2]
            end
        end
    else
        if strict
            error("invalid function format " * string( callex ) )
        else
            return ( nothing, nothing )
        end
    end
    sig = {}
    for i in 2:length( callex.args )
        sube = callex.args[i]
        if Meta.isexpr( sube, :parameters )
            continue
        end
        si = processOneSig( sube, typeHints )
        push!( sig, si )
    end
    return (funcname, sig)
end

# as part of Lint's tests
function addDummyDeprecates()
    global deprecates

    mypush! = (sym, sig)->begin
        push!( deprecates[ sym ], DeprecateInfo( sym, sig, string( sym ) * " generic deprecate message", 0 ) )
    end

    deprecates[ :testDep1 ] = DeprecateInfo[]
    mypush!( :testDep1, nothing )
    deprecates[ :testDep2 ] = DeprecateInfo[]
    mypush!( :testDep2, { ( :normal, :Integer ) } )
    deprecates[ :testDep3 ] = DeprecateInfo[]
    mypush!( :testDep3, { ( :normal, :( Array{Any, 1} ) ) } )
    deprecates[ :testDep4 ] = DeprecateInfo[]
    mypush!( :testDep4, { ( :normal, :Integer ), ( :(...), :Integer ) } )
end

# returns nothing, or DeprecateInfo
function functionIsDeprecated( callex::Expr )
    global deprecates
    if !Meta.isexpr( callex, :call )
        throw( string( callex ) )
    end
    funcname, sig = getFuncNameAndSig( callex, false )
    if funcname == nothing
        return nothing
    end
    if Meta.isexpr( funcname, :(.) )
        funcname = funcname.args[2]
    end
    if typeof( funcname ) != Symbol
        return nothing
    end
    if !haskey( deprecates, funcname )
        return nothing
    end
    for di in deprecates[ funcname ]
        if funcMatchesDeprecateInfo( sig, di )
            return di
        end
    end
    return nothing
end

function funcMatchesDeprecateInfo( sig, di::DeprecateInfo )
    if di.sig == nothing
        return true
    end

    checkIsSubType = (s1, s2) -> begin
        if s2 == :Any
            return true
        end
        if s1 == s2
            return true
        end
        if typeof( s1 ) == Symbol && typeof( s2 ) == Symbol
            ret = false
            try
                ret = eval( :( $s1 <: $s2 ) )
            end
            return ret
        elseif typeof( s1 ) == Expr && typeof( s2 ) == Expr && s1.head == s2.head && length(s1.args)==length(s2.args)
            for i in 1:length(s1.args)
                if !checkIsSubType( s1.args[i], s2.args[i] )
                    return false
                end
            end
            return true
        else
            return false
        end
    end
    for (i,si) in enumerate(sig)
        if i <= length( di.sig )
            ditype = di.sig[i][2]
        elseif !isempty( di.sig ) && di.sig[end][1] == :(...)
            ditype = di.sig[end][2]
        else # too many arguments
            return false
        end

        if i == length(sig) && si[1]==:(...) && di.sig[end][1] != :(...)
            return false
        end

        if !checkIsSubType( si[2], ditype )
            return false
        end
    end
    return true
end

if isempty( deprecates )
    initDeprecateInfo()
end
