
import Base: eltype

function keytype( ::Type{Any} )
    Any
end
function valuetype( ::Type{Any} )
    Any
end

function keytype{K,V}( ::Type{Associative{K,V}} )
    K
end
function valuetype{K,V}( ::Type{Associative{K,V}} )
    V
end
function keytype{T<:Associative}( ::Type{T} )
    keytype( super( T ) )
end
function valuetype{T<:Associative}( ::Type{T} )
    valuetype( super( T ) )
end

function eltype{T}( ::Type{Enumerate{T}})
    (Int, eltype( T ) )
end

function isAnyOrTupleAny( x )
    if x == Any
        return true
    elseif typeof( x ) <: Tuple
        return all( y->y==Any, x )
    end
    return false
end

function guesstype( ex::Any, ctx::LintContext )
    t = typeof( ex )
    if t <: Number
        return t
    end
    if t <: String
        return t
    end
    if t==Symbol # check if we have seen it
        stacktop = ctx.callstack[end]
        sym = ex
        for i in length(stacktop.localvars):-1:1
            if haskey( stacktop.localvars[i], sym )
                return stacktop.localvars[i][sym].typeactual
            end
        end
        for i in length(stacktop.localarguments):-1:1
            if haskey( stacktop.localarguments[i], sym )
                return stacktop.localarguments[i][sym].typeactual
            end
        end
        for i in length( ctx.callstack):-1:1
            if in( sym, ctx.callstack[i].types )
                return DataType
            end
            if in( sym, ctx.callstack[i].functions )
                return Function
            end
            if in( sym, ctx.callstack[i].modules )
                return Module
            end
        end
        try
            tmp = eval( Main, ex )
            return typeof( tmp )
        end
        return Any
    end

    if t == QuoteNode
        return typeof( ex.value )
    end

    if t != Expr
        return Any
    end

    if isexpr( ex, :tuple )
        ts = Any[]
        for a in ex.args
            push!( ts, guesstype( a, ctx ) )
        end
        return tuple( ts... )
    end

    if isexpr( ex, :(::) ) && length( ex.args ) == 2
        t = Any
        try
            t = eval( Main, ex.args[2] )
        end
        return t
    end

    if isexpr( ex, :block )
        return guesstype( ex.args[end], ctx )
    end

    if isexpr( ex, :call ) && ex.args[1] == :convert && typeof( ex.args[2] ) == Symbol
        ret = Any
        try
            ret = eval( Main, ex.args[2] )
        end
        return ret
    end

    # this is hackish because the return type is a Symbol, not a DataType
    if isexpr( ex, :call ) && ex.args[1] == :new
        return symbol( ctx.scope )
    end

    if isexpr( ex, :return )
        tmp = guesstype( ex.args[1], ctx )
        return tmp
    end

    if isexpr( ex, :call ) && ex.args[1] == :enumerate
        return Enumerate{ guesstype( ex.args[2], ctx ) }
    end

    if isexpr( ex, :call )
        fn = ex.args[1]
        if fn == :int
            return Int
        elseif fn == :int8
            return Int8
        elseif fn == :int16
            return Int16
        elseif fn == :int32
            return Int32
        elseif fn == :int64
            return Int64
        elseif fn == :float
            return Float64
        elseif fn == :Complex
            return Complex
        elseif fn == :Rational
            return Rational
        end
    end

    if isexpr( ex, :macrocall ) && ex.args[1] == symbol( "@sprintf" ) ||
        isexpr( ex, :call ) && in( ex.args[1], [:replace, :string, :utf8, :utf16, :utf32, :repr, :normalize_string, :join, :chop, :chomp,
            :lpad, :rpad, :strip, :lstrip, :rstrip, :uppercase, :lowercase, :ucfirst, :lcfirst,
            :escape_string, :unescape_string ] )
        return String
    end

    if isexpr( ex, :(:) )
        return Range
    end

    if isexpr( ex, :call ) && isexpr( ex.args[1], :curly )
        ret=Any
        try
            ret = eval( Main, ex.args[1] )
        end
        return ret
    end

    if isexpr( ex, :call ) && ex.args[1] == :rand
        if length(ex.args)==1
            return Float64
        else
            return Array{ Float64, length( ex.args ) - 1 }
        end
    end

    if isexpr( ex, :call ) && ex.args[1] == :Array
        ret = Array
        try
            ret = Array{ eval( Main, ex.args[2] ), length(ex.args)-2 }
        catch
            ret = Array{ Any, length(ex.args)-2 }
        end
        return ret
    end

    if isexpr( ex, :call ) && in( ex.args[1], [ :zeros, :ones ] )
        sig = Any[]
        for i = 2:length(ex.args)
            push!( sig, guesstype( ex.args[i], ctx ) )
        end
        if length( sig ) == 1
            return sig[1] # assume it's the same type, as in zeros{T}( A::AbstractArray{T,N} )
        end
        if sig[1] == DataType
            ret = Array
            try
                ret = Array{ eval( Main, ex.args[2] ), length(ex.args)-2 }
            catch
                ret = Array{ Any, length(ex.args)-2 }
            end
            return ret
        elseif all( y->y <: Integer, sig )
            return Array{ Float64, length( sig ) }
        else
            return Array
        end
    end

    if isexpr( ex, :call ) && in( ex.args[1], [ :slicedim, :transpose ] )
        fst = guesstype( ex.args[2], ctx )
        return fst
    end

    if isexpr( ex, symbol( "'" ) )
        fst = guesstype( ex.args[1], ctx )
        return fst
    end

    if isexpr( ex, :call ) && in( ex.args[1], [ :length, :sizeof ] )
        return Int
    end

    if isexpr( ex, :call ) && ex.args[1] == :reshape
        sig = Any[]
        for i = 2:length(ex.args)
            push!( sig, guesstype( ex.args[i], ctx ) )
        end
        if !( sig[1] <: AbstractArray )
            return Any
        end
        eletyp = eltype( sig[1] )
        if length(sig)==2
            if sig[2] <: Number
                return Array{ eletyp, 1 }
            elseif sig[2] <: Tuple
                return Array{ eletyp, length( sig[2] ) }
            else
                return Array{ eletyp }
            end
        else
            return Array{ eletyp, length( sig ) - 1 }
        end
    end

    if isexpr( ex, :call ) && ex.args[1] == :repeat
        ret = guesstype( ex.args[2], ctx )
        if ret <: String
            return ret
        end
    end

    if isexpr( ex, :ref ) # it could be a ref a[b] or an array Int[1,2,3]
        if typeof( ex.args[1] ) == Symbol && isupper( string( ex.args[1] )[1] ) # assume an array
            elt = Any
            try
                elt = eval( Main, ex.args[1] )
            end
            if typeof( elt ) == DataType
                return Array{ elt, 1 }
            end
        else
            partyp = guesstype( ex.args[1], ctx )
            if partyp <: Array
                eletyp = eltype( partyp )
                try
                    nd = ndims( partyp ) # This may throw if we couldn't infer the dimension
                    tmpdim = nd - (length( ex.args )-1)
                    if tmpdim < 0
                        msg( ctx, 2, string( ex ) * " has more indices than dimensions")
                        return Any
                    end

                    for i in 2:length( ex.args )
                        if ex.args[i] == :(:)
                            tmpdim += 1
                        end
                    end
                    if tmpdim != 0
                        return Array{ eletyp, tmpdim } # is this strictly right?
                    else
                        return eletyp
                    end
                end
                return Any
            elseif partyp <: Associative
                ktypeexpect = keytype( partyp )
                vtypeexpect = valuetype( partyp )
                ktypeactual = guesstype( ex.args[2], ctx )
                if ktypeactual != Any && !( ktypeactual <: ktypeexpect )
                    msg( ctx, 2, "Key type expects " * string( ktypeexpect ) * ", provided " * string( ktypeactual ) )
                end
                return vtypeexpect
            end
        end
        return Any
    end

    if isexpr( ex, :typed_dict ) && isexpr( ex.args[1], :(=>) ) &&
        typeof( ex.args[1].args[1] ) == Symbol && typeof( ex.args[1].args[2] ) == Symbol
        ret = Dict
        try
            ret = Dict{ eval( Main, ex.args[1].args[1] ), eval( Main, ex.args[1].args[2] ) }
        end
        return ret
    end
    if isexpr( ex, :dict )
        return Dict
    end
    if isexpr( ex, :comparison )
        return Bool
    end

    # simple if statement e.g. test ? 0 : 1
    if isexpr( ex, :if ) && length( ex.args ) == 3
        tt = guesstype( ex.args[2], ctx )
        ft = guesstype( ex.args[3], ctx )
        if tt == ft
            return tt
        else
            return Any
        end
    end

    if isexpr( ex, :(->))
        return Function
    end

    return Any
end
