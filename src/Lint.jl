# Julia's homoiconicity is crying out for an awesome lint module

module Lint

using Base.Meta

export LintMessage, LintContext, LintStack
export lintfile, lintstr, lintpkg, lintpragma
export test_similarity_string

const SIMILARITY_THRESHOLD = 10.0
const ASSIGN_OPS = [ :(=), :(+=), :(-=), :(*=), :(/=), :(&=), :(|=) ]

# Wishlist:
# setting a value to a datatype instead of an instance of that type
# warn push! vs append! (requires understanding of types)
# warn eval

include( "linttypes.jl" )
include( "knownsyms.jl")
include( "guesstype.jl" )
include( "variables.jl" )
include( "functions.jl" )
include( "types.jl" )
include( "modules.jl" )
include( "blocks.jl" )
include( "controls.jl" )
include( "macros.jl" )
include( "knowndeprec.jl" )
include( "misc.jl")

# no-op, the presence of this can suppress lint messages locally
function lintpragma( s::String )
end

function lintpkg( pkg::String; returnMsgs::Bool = false )
    p = joinpath( Pkg.dir( pkg ), "src", pkg * ".jl" )
    if !ispath( p )
        throw( "cannot find path: " * p )
    end
    lintfile( p, returnMsgs = returnMsgs )
end

function lintfile( file::String; returnMsgs::Bool = false )
    if !ispath( file )
        throw( "no such file exists")
    end

    ctx = LintContext()
    ctx.file = file
    ctx.path = dirname( file )
    str = open(readall, file)
    msgs = lintstr( str, ctx )
    sort!( msgs )
    delids = Int[]
    for i in 2:length( msgs )
        if  msgs[i] == msgs[i-1]
            push!( delids, i )
        end
    end
    deleteat!( msgs, delids )
    for m in msgs
        colors = [ :normal, :yellow, :magenta, :red ]
        Base.println_with_color( colors[m.level+1], string(m) )
    end
    if returnMsgs
        return msgs
    else
        return nothing
    end
end

function lintstr( str::String, ctx :: LintContext = LintContext(), lineoffset = 0 )
    if VERSION < v"0.4-"
        linecharc = cumsum( map( x->length(x)+1, split( str, "\n", true ) ) )
    else
        linecharc = cumsum( map( x->length(x)+1, split( str, "\n", keep=true ) ) )
    end
    i = start(str)
    while !done(str,i)
        problem = false
        ex = nothing
        ctx.lineabs = searchsorted( linecharc, i ).start + lineoffset
        try
            (ex, i) = parse(str,i)
        catch y
            if typeof( y ) != ParseError || y.msg != "end of input"
                msg( ctx, 2, string(y) )
            end
            problem = true
        end
        if !problem
            lintexpr( ex, ctx )
        else
            break
        end
    end
    return ctx.messages
end

function msg( ctx, lvl, str )
    push!( ctx.messages, LintMessage( ctx.file , ctx.scope,
            ctx.lineabs + ctx.line-1, lvl, str ) )
end

function lintexpr( ex::Any, ctx::LintContext )
    if typeof(ex) == Symbol
        if ctx.quoteLvl == 0
            registersymboluse( ex, ctx )
        end
        return
    end

    if typeof(ex) == QuoteNode && typeof( ex.value ) == Expr
        ctx.quoteLvl += 1
        lintexpr( ex.value, ctx )
        ctx.quoteLvl -= 1
    end

    if typeof(ex)!=Expr
        return
    end

    for h in values( ctx.callstack[end].linthelpers )
        if h( ex, ctx ) == true
            return
        end
    end

    if ex.head == :block
        lintblock( ex, ctx )
    elseif ex.head == :if
        lintifexpr( ex, ctx )
    elseif ex.head == :(=) && typeof(ex.args[1])==Expr && ex.args[1].head == :call
        lintfunction( ex, ctx )
    elseif in( ex.head, ASSIGN_OPS )
        lintassignment( ex, ctx )
    elseif ex.head == :local
        lintlocal( ex, ctx )
    elseif ex.head == :global
        lintglobal( ex, ctx )
    elseif ex.head == :const
        if typeof( ex.args[1] ) == Expr && ex.args[1].head == :(=)
            lintassignment( ex.args[1], ctx; isConst = true )
        end
    elseif ex.head == :module
        lintmodule( ex, ctx )
    elseif ex.head == :using
        lintusing( ex, ctx )
    elseif ex.head == :export
        lintexport( ex, ctx )
    elseif ex.head == :import # single name import. e.g. import Base
        lintimport( ex, ctx )
    elseif ex.head == :importall
        lintimport( ex, ctx; all=true )
    elseif ex.head == :comparison # only the odd indices
        for i in 1:2:length(ex.args)
            # comparison like match != 0:-1 is allowed, and shouldn't trigger lint warnings
            if Meta.isexpr( ex.args[i], :(:) ) && length( ex.args[i].args ) == 2 &&
                typeof( ex.args[i].args[1] ) <: Real &&
                typeof( ex.args[i].args[2] ) <: Real
                continue
            else
                lintexpr( ex.args[i], ctx )
            end
        end
    elseif ex.head == :type
        linttype( ex, ctx )
    elseif ex.head == :typealias
        linttypealias( ex, ctx )
    elseif ex.head == :abstract
        lintabstract( ex, ctx )
    elseif ex.head == :(->)
        lintlambda( ex, ctx )
    elseif ex.head == :($) && ctx.quoteLvl > 0 # an unquoted node inside a quote node
        ctx.quoteLvl -= 1
        lintexpr( ex.args[1], ctx )
        ctx.quoteLvl += 1
    elseif ex.head == :function
        lintfunction( ex, ctx )
    elseif ex.head == :macro
        lintmacro( ex, ctx )
    elseif ex.head == :macrocall
        lintmacrocall( ex, ctx )
    elseif ex.head == :call
        lintfunctioncall( ex, ctx )
    elseif ex.head == :(:)
        lintrange( ex, ctx )
    elseif ex.head == :(::) # type assert/convert
        lintexpr( ex.args[1], ctx )
    elseif ex.head == :(.) # a.b
        lintexpr( ex.args[1], ctx )
    elseif ex.head == :ref # it could be a ref a[b], or an array Int[1,2]
        sub1 = ex.args[1]
        guesstype( ex, ctx ) # tickle the type checks on the expression
        if typeof(sub1)== Symbol
            # check to see if it's a type
            str = string( sub1)
            if !isupper( str[1] )
                registersymboluse( sub1,ctx )
            end
        else
            lintexpr(sub1, ctx)
        end
        for i=2:length(ex.args)
            lintexpr( ex.args[i], ctx )
        end
    elseif ex.head == :dict # homogeneous dictionary
        lintdict( ex, ctx; typed=false )
    elseif ex.head == :typed_dict # mixed type dictionary
        lintdict( ex, ctx; typed=true )
    elseif ex.head == :vcat
        lintvcat( ex, ctx )
    elseif ex.head == :while
        lintwhile( ex, ctx )
    elseif ex.head == :for
        lintfor( ex, ctx )
    elseif ex.head == :let
        lintlet( ex, ctx )
    elseif ex.head == :comprehension || ex.head == :dict_comprehension
        lintcomprehension( ex, ctx; typed = false )
    elseif ex.head == :typed_comprehension || ex.head == :typed_dict_comprehension
        lintcomprehension( ex, ctx; typed = true )
    elseif ex.head == :try
        linttry( ex, ctx )
    elseif ex.head == :curly # e.g. Ptr{T}
        return
    else
        for sube in ex.args
            if typeof(sube)== Expr
                lintexpr(sube, ctx )
            elseif typeof(sube)==Symbol
                registersymboluse( sube, ctx )
            end
        end
    end
end

end

Lint.initcommoncollfuncs()
