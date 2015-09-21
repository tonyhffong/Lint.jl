
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

if VERSION < v"0.4-dev+3345"
function eltype{T}( ::Type{Enumerate{T}})
    (Int, T )
end
#else
#function eltype{T}( ::Type{Enumerate{T}})
#    Tuple{Int, T }
#end
end

function isAnyOrTupleAny( x )
    if x == Any
        return true
    elseif typeof( x ) <: Tuple
        return all( y->y==Any, x )
    end
    return false
end

# ex should be a type. figure out what it is
function parsetype( ex )
    ret = Any
    if typeof( ex ) <: Symbol
        try
            ret = eval( Main, ex )
        end
        return ret
    elseif typeof( ex ) <: Expr
        if isexpr( ex, :curly )
            if ex.args[1] == :Array
                elt = Any
                if length( ex.args ) == 1
                    return Array
                elseif length( ex.args ) >= 2
                    elt = Any
                    try
                        elt = eval( Main, ex.args[2] )
                    end
                    if length(ex.args ) == 2
                        return Array{ elt }
                    else
                        if typeof( ex.args[3] ) <: Integer
                            return Array{ elt, ex.args[3] }
                        else
                            return Array{ elt }
                        end
                    end
                end
            elseif ex.args[1] == :Dict
                if length( ex.args ) == 1
                    return Dict
                elseif length( ex.args ) == 3
                    kt = parsetype( ex.args[2] )
                    vt = parsetype( ex.args[3] )
                    return Dict{kt, vt}
                end
            elseif ex.args[1] == :Vector
                if length( ex.args ) != 2
                    return Vector
                else
                    vt = parsetype( ex.args[2] )
                    return Vector{vt}
                end
            elseif ex.args[1] == :Complex
                if length( ex.args ) != 2
                    return Complex
                else
                    vt = parsetype( ex.args[2] )
                    return Complex{vt}
                end
            end
        end
    end
    return ret
end

function guesstype( ex, ctx::LintContext )
    t = typeof( ex )
    if t <: Number
        return t
    end
    if t <: AbstractString
        return t
    end
    if t==Symbol # check if we have seen it
        if ex == :nothing
            return Void
        end
        # TODO: this should be a module function
        checkret = x -> begin
            if typeof( x ) == DataType || typeof( x ) == (DataType,)
                return x
            else
                tmp = x
                try
                    tmp = eval( x )
                end
                if typeof( tmp ) == DataType || typeof( tmp ) == (DataType,)
                    return tmp
                else
                    return x
                end
            end
        end
        stacktop = ctx.callstack[end]
        sym = ex
        for i in length(stacktop.localvars):-1:1
            if haskey( stacktop.localvars[i], sym )
                ret = stacktop.localvars[i][sym].typeactual
                return checkret( ret )
            end
        end
        for i in length(stacktop.localarguments):-1:1
            if haskey( stacktop.localarguments[i], sym )
                ret = stacktop.localarguments[i][sym].typeactual
                return checkret( ret )
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
        if VERSION < v"0.4.0-dev+4319"
            return tuple( ts... )
        else
            return Tuple{ ts... }
        end
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
        return Symbol( ctx.scope )
    end

    # another detection for constructor calling another constructor
    # A() = A(default)
    if isexpr( ex, :call ) && Symbol( ctx.scope ) == ex.args[1]
        found = false
        for i = length( ctx.callstack ):-1:1
            found = in( ex.args[1], ctx.callstack[i].types )
            if found
                return ex.args[1]
            end
        end
    end
    # A() = A{T}(default)
    if isexpr( ex, :call ) && isexpr( ex.args[1], :curly ) && Symbol( ctx.scope ) == ex.args[1].args[1]
        found = false
        for i = length( ctx.callstack ):-1:1
            found = in( ex.args[1].args[1], ctx.callstack[i].types )
            if found
                return ex.args[1].args[1]
            end
        end
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

    if isexpr( ex, :macrocall )
        if ex.args[1] == Symbol( "@sprintf" ) ||
            isexpr( ex, :call ) && in( ex.args[1], [:replace, :string, :utf8, :utf16, :utf32, :repr, :normalize_string, :join, :chop, :chomp,
            :lpad, :rpad, :strip, :lstrip, :rstrip, :uppercase, :lowercase, :ucfirst, :lcfirst,
            :escape_string, :unescape_string ] )
            return AbstractString
        elseif ex.args[1] == Symbol( "@compat" )
            return guesstype( ex.args[2], ctx )
        end
    end

    if isexpr( ex, :(:) )
        return Range
    end

    if isexpr( ex, :curly )
        return DataType
    end

    if isexpr( ex, :call ) && isexpr( ex.args[1], :curly )
        ret=parsetype( ex.args[1] )
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
        elt = Any
        try
            elt = eval( Main, ex.args[2] )
        end

        try
            if length(ex.args) == 3
                if isexpr( ex.args[3], :tuple )
                    ret = Array{ elt, length(ex.args[3].args) }
                else
                    lastargtype = guesstype( ex.args[3], ctx )
                    if lastargtype <: Integer
                        ret = Array{ elt, 1 }
                    elseif lastargtype <: Tuple && all( x->x<:Integer, lastargtype )
                        if VERSION < v"0.4.0-dev+4319"
                            ret = Array{ elt, length( lastargtype ) }
                        else
                            ret = Array{ elt, length( lastargtype.parameters ) }
                        end
                    else
                        ret = Array{ elt }
                    end
                end
            else
                ret = Array{ elt, length(ex.args)-2 }
            end
        end
        return ret
    end

    if isexpr( ex, :call ) && in( ex.args[1], [ :zeros, :ones ] )
        sig = Any[]
        for i = 2:length(ex.args)
            push!( sig, guesstype( ex.args[i], ctx ) )
        end
        elt = Any
        try
            elt = eval( Main, ex.args[2] )
        end
        if length(sig) >= 1 && sig[1] == DataType
            if length(sig) == 2 && isexpr(ex.args[3],:tuple)
                ret = Array{ elt, length(ex.args[3].args ) }
            elseif length(sig) == 2 && sig[2] <: Tuple && all( x->x <: Integer, sig[2] )
                if VERSION < v"0.4.0-dev+4319"
                    ret = Array{ elt, length( sig[2] ) }
                else
                    ret = Array{ elt, length( sig[2].parameters ) }
                end
            else
                ret = Array{ elt, length(ex.args)-2 }
            end
            return ret
        elseif all( y->y <: Integer, sig )
            return Array{ Float64, length( sig ) }
        elseif length( sig ) == 1 && sig[1] <: Array
            return sig[1]
        else
            return Array
        end
    end

    if isexpr( ex, :call ) && in( ex.args[1], [ :slicedim, :transpose ] )
        fst = guesstype( ex.args[2], ctx )
        return fst
    end

    if isexpr( ex, Symbol( "'" ) )
        fst = guesstype( ex.args[1], ctx )
        return fst
    end

    if isexpr( ex, :call ) && in( ex.args[1], [ :length, :sizeof ] )
        return Int
    end

    if isexpr( ex, :call ) && in( ex.args[1], [:size] )
        fst = guesstype( ex.args[2], ctx)
        if fst <: Array
            ret = Any
            try
                nd = ndims( fst )
                if nd == 1 || length( ex.args ) == 3
                    ret = Int
                else
                    @lintpragma( "Ignore unused i" )
                    if VERSION < v"0.4.0-dev+4319"
                        ret = tuple( DataType[ Int for i=1:nd ]... )
                    else
                        ret = Tuple{ DataType[ Int for i=1:nd ]... }
                    end
                end
            end
            return ret
        end
        return Any
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
        #dump( eletyp )
        if length(sig)==2
            if sig[2] <: Number
                return Array{ eletyp, 1 }
            elseif sig[2] <: Tuple
                if VERSION < v"0.4.0-dev+4319"
                    return Array{ eletyp, length( sig[2] ) }
                else
                    return Array{ eletyp, length( sig[2].parameters ) }
                end
            else
                return Array{ eletyp }
            end
        else
            return Array{ eletyp, length( sig ) - 1 }
        end
    end

    if isexpr( ex, :call ) && ex.args[1] == :repeat
        ret = guesstype( ex.args[2], ctx )
        if ret <: AbstractString
            return ret
        end
    end

    if isexpr( ex, :call ) && ex.args[1] == :Dict
        return Dict
    end

    if isexpr( ex, :ref ) # it could be a ref a[b] or an array Int[1,2,3], Vector{Int}[]
        if isexpr( ex.args[1], :curly ) # must be a datatype, right?
            elt = parsetype( ex.args[1] )
            return Array{ elt, 1 }
        end

        if typeof( ex.args[1] ) == Symbol
            what = registersymboluse( ex.args[1], ctx, false )
            if what == :DataType
                elt = parsetype( ex.args[1] )
                return Array{ elt, 1 }
            elseif what == :Any
                msg( ctx, 1, "Lint cannot determine if " * string( ex.args[1] ) * " is a DataType or not" )
                return Any
            end
        end
        # not symbol, or symbol but it refers to a variable
        partyp = guesstype( ex.args[1], ctx )
        if typeof( partyp ) == Symbol # we are in a context of a constructor of a new type, so it's difficult to figure out the content
            return Any
        elseif partyp <: UnitRange
            ktypeactual = guesstype( ex.args[2], ctx )
            if ktypeactual <: Integer
                return eltype( partyp )
            elseif isexpr( ex.args[2], :(:) ) # range too
                return partyp
            elseif isexpr( ex.args[2], :call ) && ex.args[2].args[1] == :Colon
                return partyp
            else
                return Any
            end
        elseif partyp <: AbstractArray
            eletyp = eltype( partyp )
            try
                nd = ndims( partyp ) # This may throw if we couldn't infer the dimension
                tmpdim = nd - (length( ex.args )-1)
                if tmpdim < 0
                    if nd == 0 && ex.args[2] == 1 # ok to do A[1] for a 0-dimensional array
                        return eletyp
                    else
                        msg( ctx, 2, string( ex ) * " has more indices than dimensions")
                        return Any
                    end
                end

                for i in 2:length( ex.args )
                    if ex.args[i] == :(:) || isexpr( ex.args[i], :call ) && ex.args[i].args[1] == :Colon
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
        elseif typeof( partyp ) == (DataType,) # e.g. (Int,), (Int...,), (DataType,...)
            fst = partyp[1]
            try
                if fst.name.name == :Vararg
                    return fst.parameters[1]
                else
                    return fst
                end
            catch
                return Any
            end
        elseif partyp <: Associative
            ktypeexpect = keytype( partyp )
            vtypeexpect = valuetype( partyp )
            ktypeactual = guesstype( ex.args[2], ctx )
            if ktypeactual != Any && !( ktypeactual <: ktypeexpect )
                msg( ctx, 2, "Key type expects " * string( ktypeexpect ) * ", provided " * string( ktypeactual ) )
            end
            return vtypeexpect
        elseif partyp <: AbstractString
            ktypeactual = guesstype( ex.args[2], ctx )
            if ktypeactual != Any && !( ktypeactual <: Integer ) && !( ktypeactual <: Range )
                msg( ctx, 2, "string[] expects Integer, provided " * string( ktypeactual ) )
            end
            if ktypeactual <: Integer
                return Char
            end
            if ktypeactual <: Range
                return partyp
            end
        elseif partyp <: Tuple
            if VERSION < v"0.4.0-dev+4139"
                if isempty( partyp )
                    return Any
                end
                if length( partyp ) == 1 || partyp[1].name.name == :Vararg
                    return eval( Main, partyp[1].name.name )
                end
                elt = partyp[1]
                if all( x->x == elt, partyp )
                    return elt
                end
            else
                if isempty( partyp.parameters )
                    return Any
                end
                if length( partyp.parameters ) == 1 || partyp.parameters[1].name.name == :Vararg
                    return eval( Main, partyp.parameters[1].parameters[1].name.name )
                end
                elt = partyp.parameters[1]
                if all( x->x == elt, partyp.parameters )
                    return elt
                end
            end
        #=
        elseif isdefined( Main, :AbstractDataFrame ) && partyp <: AbstractDataFrame
            ktypeactual = guesstype( ex.args[2], ctx )
            if ktypeactual <: Symbol || ktypeactual <: Integer
                return AbstractDataArray
            else
                return Any
            end
        =#
        elseif partyp != Any
            if ctx.versionreachable( VERSION ) && !pragmaexists( string( partyp ) * " is a container type", ctx )
                msg( ctx, 2, string( ex.args[1] ) * " has apparent type " * string( partyp ) * ", not a container type." )
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
