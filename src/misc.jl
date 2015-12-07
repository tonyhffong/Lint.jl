# misc easy to make mistakes

function lintrange( ex::Expr, ctx::LintContext )
    if length( ex.args ) == 2 && typeof( ex.args[1] ) <: Real &&
            typeof( ex.args[2] ) <: Real && ex.args[2] < ex.args[1]
        msg( ctx, :ERROR, "For a decreasing range, use a negative step e.g. 10:-1:1")
    else
        for a in ex.args
            lintexpr( a, ctx )
        end
    end
end

function lintvcat( ex::Expr, ctx::LintContext )
    for a in ex.args
        if isexpr( a, :vcat )
            msg( ctx, :WARN, "Nested vcat is treated as a 1-dimensional array." )
        end
        lintexpr( a, ctx )
    end
end

function lintvect( ex::Expr, ctx::LintContext )
    for a in ex.args
        if isexpr( a, :vect )
            msg( ctx, :ERROR, "Nested vect is treated as a 1-dimensional array. Use [a;b] instead" )
        end
        lintexpr( a, ctx )
    end
end

function linthcat( ex::Expr, ctx::LintContext )
    for a in ex.args
        if isexpr( a, :hcat )
            msg( ctx, :WARN, "Nested hcat is treated as a 1-row horizontal array of dim=2." )
        end
        lintexpr( a, ctx )
    end
end

function linttyped_hcat( ex::Expr, ctx::LintContext )
    #dump(ex)
    if length( ex.args ) == 3
        if ex.args[3] == QuoteNode( Symbol( "end" ) )
            msg( ctx, :INFO, "Ambiguity of :end as a symbol vs as part of a range." )
        elseif ex.args[2] == Symbol( "end" ) && typeof( ex.args[3] ) <: Integer &&
            ex.args[3] < 0
            msg( ctx, :INFO, "Ambiguity of `[end -n]` as a matrix row vs index [end-n]")
        end
    end
    for a in ex.args
        lintexpr( a, ctx )
    end
end

function lintcell1d( ex::Expr, ctx::LintContext )
    if VERSION < v"0.4-"
        msg( ctx, :INFO, "{} may be deprecated in Julia 0.4. Use Any[]" )
    end
    for a in ex.args
        lintexpr( a, ctx )
    end
end
