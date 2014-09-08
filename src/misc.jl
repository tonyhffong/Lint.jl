# misc easy to make mistakes

function lintdict( ex::Expr, ctx::LintContext; typed::Bool = false )
    st = typed ? 2 : 1
    ks = Set{Any}()
    ktypes = Set{Any}()
    vtypes = Set{Any}()
    for i in st:length(ex.args)
        a = ex.args[i]
        if typeof(a)== Expr && a.head == :(=>)
            if typeof( a.args[1] ) != Expr
                if in( a.args[1], ks )
                    msg( ctx, 2, "Duplicate key in Dict: " * string( a.args[1] ) )
                end
                push!( ks, a.args[1] )
            end
            for (j,s) in [ (1,ktypes), (2,vtypes ) ]
                if typeof( a.args[j] ) <: QuoteNode && typeof( a.args[j].value ) <: Symbol
                    push!( s, Symbol )
                elseif typeof( a.args[j] ) <: Number || typeof( a.args[j] ) <: String
                    push!( s, typeof( a.args[j] ) )
                    # we want to add more immutable types such as Date, DateTime, etc.
                elseif isexpr( a.args[j], :call ) && in( a.args[j].args[1], [:Date, :DateTime] )
                    push!( s, a.args[j].args[1] )
                else
                    if typed
                        push!( s, Any )
                    end
                end
            end

            lintexpr( a.args[2], ctx )
        end
    end

    if !typed
        if length( ktypes ) > 1
            msg( ctx, 2, "Multiple key types detected. Use {} for mixed type dict")
        end
        if length( vtypes ) > 1
            msg( ctx, 2, "Multiple value types detected. Use {} for mixed type dict")
        end
    else
        # if the expression is explicitly (Any=>Any)[ :a => 1 ], then it'd be
        #   :Any=>:Any, not TopNode( :Any )=>TopNode( :Any )
        declktype = ex.args[1].args[1]
        declvtype = ex.args[1].args[2]
        if declktype == TopNode( :Any ) && declvtype == TopNode( :Any ) &&
            !in( Any, ktypes ) && length( ktypes ) == 1 &&
            !in( Any, vtypes ) && length( vtypes ) == 1
            msg( ctx, 0, "There is only 1 key type && 1 value type. Use [] for better performances.")
        end
    end
end

function lintrange( ex::Expr, ctx::LintContext )
    if length( ex.args ) == 2 && typeof( ex.args[1] ) <: Real && typeof( ex.args[2] ) <: Real && ex.args[2] < ex.args[1]
        msg( ctx, 2, "For a decreasing range, use a negative step e.g. 10:-1:1")
    else
        for a in ex.args
            lintexpr( a, ctx )
        end
    end
end

function lintvcat( ex::Expr, ctx::LintContext )
    for a in ex.args
        if isexpr( a, :vcat )
            msg( ctx, 1, "Nested vcat is treated as a 1-dimensional array." )
        end
        lintexpr( a, ctx )
    end
end
