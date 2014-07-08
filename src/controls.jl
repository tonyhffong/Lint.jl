function lintifexpr( ex::Expr, ctx::LintContext )
    if ex.args[1] == false
        msg( ctx, 1, "true branch is unreachable")
        if length(ex.args) > 2
            lintexpr( ex.args[3], ctx )
        end
    elseif ex.args[1] == true
        lintexpr( ex.args[2], ctx )
        if length(ex.args) > 2
            msg( ctx, 1, "false branch is unreachable")
        else
            msg( ctx, 1, "redundant if-true statement")
        end
    else
        if typeof(ex.args[1]) == Expr
            lintboolean( ex.args[1], ctx )
        end
        lintexpr( ex.args[2], ctx )
        if length(ex.args) > 2
            lintexpr( ex.args[3], ctx )
        end
    end
end

function lintboolean( ex::Expr, ctx::LintContext )
    if ex.head == :(=)
        msg( ctx, 0, "Assignment in the if-predicate clause.")
    elseif ex.head == :call && ex.args[1] in [ :(&), :(|), :($) ]
        msg( ctx, 1, "Bit-wise " * string( ex.args[1]) * " in a boolean context. (&,|) do not have short-circuit behavior." )
    elseif ex.head == :(&&) || ex.head == :(||)
        for a in ex.args
            if typeof(a) == Symbol
                registersymboluse(a, ctx)
            elseif typeof(a)== Expr
                lintboolean( a, ctx )
            else
                msg( ctx, 2, "Lint doesn't understand " * string( a ) * " in a boolean context." )
            end
        end
    elseif ex.head ==:call && ex.args[1] == :(!)
        for i in 2:length(ex.args)
            a = ex.args[i]
            if typeof(a) == Symbol
                registersymboluse(a, ctx)
            elseif typeof(a)== Expr
                lintboolean( a, ctx )
            else
                msg( ctx, 2, "Lint doesn't understand " * string( a ) * " in a boolean context." )
            end
        end
    elseif ex.head == :call && ex.args[1] == :length
        msg( ctx, 2, "Incorrect usage of length() in a Boolean context. You want to use isempty().")
    end
    lintexpr( ex, ctx )
end

function lintfor( ex::Expr, ctx::LintContext )
    pushVarScope( ctx )

    if typeof(ex.args[1])==Expr && ex.args[1].head == :(=)
        lintassignment( ex.args[1], ctx; isForLoop=true )
    end
    lintexpr( ex.args[2], ctx )

    popVarScope( ctx )
end

function lintwhile( ex::Expr, ctx::LintContext )
    if ex.args[1] == false
        msg( ctx, 1, "while false block is unreachable")
    elseif typeof(ex.args[1]) == Expr
            lintboolean( ex.args[1], ctx )
    end
    pushVarScope( ctx )
    lintexpr( ex.args[2], ctx )
    popVarScope( ctx )
end

function lintcomprehension( ex::Expr, ctx::LintContext; typed::Bool = false )
    pushVarScope( ctx )
    st = typed? 3 :2
    fn = typed? 2 :1
    for i in st:length(ex.args)
        if typeof(ex.args[i])==Expr && ex.args[i].head == :(=)
            lintassignment( ex.args[i], ctx; islocal=true, isForLoop=true ) # note contrast with for loop
        end
    end
    lintexpr( ex.args[fn], ctx )
    popVarScope( ctx )
end
