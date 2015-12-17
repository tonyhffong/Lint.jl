function lintifexpr(ex::Expr, ctx::LintContext)
    if ex.args[1] == false
        msg(ctx, :W642, "true branch is unreachable")
        if length(ex.args) > 2
            lintexpr(ex.args[3], ctx)
        end
    elseif ex.args[1] == true
        lintexpr(ex.args[2], ctx)
        if length(ex.args) > 2
            msg(ctx, :W643, "false branch is unreachable")
        else
            msg(ctx, :W644, "redundant if-true statement")
        end
    else
        lintboolean(ex.args[1], ctx)
        # if the first "meaty" expression under the true branch is
        # a boolean expression (!=, ==, >=, <=, >, <, &&, ||),
        # generate a INFO, as it could have been a typo
        if isexpr(ex.args[2], :block) && length(ex.args[2].args) >= 2 &&
                (isexpr(ex.args[2].args[2], :comparison) ||
                isexpr(ex.args[2].args[2], :call) && ex.args[2].args[2].args[1] == :(!) ||
                isexpr(ex.args[2].args[2], [:(&&), :(||)]) &&
                !isexpr(ex.args[2].args[2].args[end], [:call, :error, :throw, :return]))
            msg(ctx, :I571, "the 1st statement under the true-branch is a boolean expression. Typo?")
        end
        (verconstraint1, verconstraint2) = versionconstraint(ex.args[1])
        if verconstraint1 != nothing
            tmpvtest = ctx.versionreachable
            ctx.versionreachable = _->(tmpvtest(_) && verconstraint1(_))
        end
        lintexpr(ex.args[2], ctx)
        if verconstraint1 != nothing
            ctx.versionreachable = tmpvtest
        end
        if length(ex.args) > 2
            if verconstraint2 != nothing
                tmpvtest = ctx.versionreachable
                ctx.versionreachable = _->(tmpvtest(_) && verconstraint2(_))
            end
            lintexpr(ex.args[3], ctx)
            if verconstraint2 != nothing
                ctx.versionreachable = tmpvtest
            end
        end
    end
end

# return a duplet of functions, the true branch version predicate and the false-branch version predicate
# if none exists, return (nothing, nothing)
function versionconstraint(ex)
    if isexpr(ex, :comparison)
        if in(:VERSION, ex.args)
            for i = 1:2:length(ex.args)
                a = ex.args[i]
                if a == :VERSION
                    continue
                end
                if !isexpr(a, :macrocall) || a.args[1] != Symbol("@v_str") ||
                        !(typeof(a.args[2]) <: AbstractString)
                    return (nothing, nothing)
                end
            end
            localex = deepcopy(ex)
            for i in 1:length(localex.args)
                if localex.args[i] == :VERSION
                    localex.args[1] = :_
                end
            end
            l = eval(Main, Expr(:(->), :_, localex))
            return (l, _ -> !(l(_)))
        else
            return (nothing, nothing)
        end
    elseif isexpr(ex, :(&&))
        vc1 = versionconstraint(ex.args[1])
        vc2 = versionconstraint(ex.args[2])
        arr = Any[]
        if vc1[1] != nothing
            if vc2[1] != nothing
                push!(arr, _->vc1[1](_) && vc2[1](_))
            else
                push!(arr, vc1[1])
            end
        elseif vc2[1] != nothing
            push!(arr, vc2[1])
        else
            push!(arr, nothing)
        end
        if vc1[2] != nothing && vc2[2] != nothing
            push!(arr, _->vc1[2](_) || vc2[2](_))
        else
            push!(arr, nothing)
        end
        return tuple(arr...)
    elseif isexpr(ex, :(||))
        vc1 = versionconstraint(ex.args[1])
        vc2 = versionconstraint(ex.args[2])
        arr = Any[]
        if vc1[1] != nothing && vc2[1] != nothing
                push!(arr, _->vc1[1](_) || vc2[1](_))
        else
            push!(arr, nothing)
        end

        if vc1[2] != nothing
            if vc2[2] != nothing
                push!(arr, _->vc1[2](_) && vc2[2](_))
            else
                push!(arr, vc1[2])
            end
        else
            if vc2[2] != nothing
                push!(arr, vc2[2])
            else
                push!(arr, nothing)
            end
        end
        return tuple(arr...)
    elseif isexpr(ex, :call) && ex.args[1] == :(!)
        (v1,v2) = versionconstraint(ex.args[2])
        return (v2, v1)
    end
    return (nothing, nothing)
end

# expect ex would compute into a boolean
function lintboolean(ex, ctx::LintContext)
    if typeof(ex) <: Expr
        if ex.head == :(=)
            msg(ctx, :I472, "assignment in the if-predicate clause")
        elseif ex.head == :call && ex.args[1] in [:(&), :(|), :($)]
            msg(ctx, :W442, ex.args[1], "bit-wise $(ex.args[1]) in a boolean " *
                "context. (&,|) do not have short-circuit behavior")
        elseif ex.head == :(&&) || ex.head == :(||)
            n = length(ex.args)
            for a in ex.args
                lintboolean(a, ctx)
            end
        elseif ex.head ==:call && ex.args[1] == :(!)
            for i in 2:length(ex.args)
                a = ex.args[i]
                lintboolean(a, ctx)
            end
        elseif ex.head == :comparison
            lintcomparison(ex, ctx)
        elseif ex.head == :call && ex.args[1] == :length
            msg(ctx, :E431, ex.args[1], "incorrect usage of length() in a Boolean " *
                "context. You want to use isempty()")
        end
    elseif typeof(ex) == Symbol
        # can we figure of if that symbol is Bool?
        gt = guesstype(ex, ctx)
        if gt != Any && gt != Bool
            msg(ctx, :E511, ex, "variable $(ex) has apparent non-Bool type")
        end
    elseif typeof(ex) != Bool
        msg(ctx, :E512, ex, "Lint doesn't understand $(ex) in a boolean context")
    end

    if typeof(ex) <: Expr || typeof(ex) == Symbol
        lintexpr(ex, ctx)
    end
end

function lintcomparison(ex::Expr, ctx::LintContext)
    if ctx.quoteLvl != 0
        return
    end
    pos = 0
    lefttype = Any
    righttype = Any
    for i in 2:2:length(ex.args)
        if ex.args[i] in [:(==), :(<), :(>), :(<=), :(>=), :(!=)]
            if pos != i-1
                pos = i-1
                lefttype = guesstype(ex.args[i-1], ctx)
            end
            righttype = guesstype(ex.args[i+1], ctx)
            if lefttype != Any && righttype != Any
                problem = false
                if lefttype <: Number && righttype <: Number &&
                        !(lefttype <: Real && righttype <: Real) &&
                        !in(ex.args[i], [:(==), :(!=)]) # non-real comparison can only be == or !=
                    problem = true
                end
                if !problem && (!(lefttype <: Number) || !(righttype <: Number)) &&
                       !(lefttype <: righttype) && !(righttype <: lefttype)
                    problem = true
                end
                if problem && !pragmaexists(utf8("Ignore incompatible type comparison"), ctx)
                    msg(ctx, :W542, "comparing apparently incompatible types " *
                        "(#$(i>>1)) LHS:$(lefttype) RHS:$(righttype)")
                end
            end
            lefttype = righttype
            pos += 2
        end
    end
end

function lintfor(ex::Expr, ctx::LintContext)
    pushVarScope(ctx)

    if isexpr(ex.args[1], :(=))
        lintassignment(ex.args[1], :(=), ctx; isForLoop=true)
    elseif isexpr(ex.args[1], :block)
        for a in ex.args[1].args
            if isexpr(a, :(=))
                lintassignment(a, :(=), ctx; isForLoop=true)
            end
        end
    end
    lintexpr(ex.args[2], ctx)

    popVarScope(ctx)
end

function lintwhile(ex::Expr, ctx::LintContext)
    if ex.args[1] == false
        msg(ctx, :W645, "while false block is unreachable")
    elseif typeof(ex.args[1]) == Expr
            lintboolean(ex.args[1], ctx)
    end
    pushVarScope(ctx)
    lintexpr(ex.args[2], ctx)
    popVarScope(ctx)
end

function lintcomprehension(ex::Expr, ctx::LintContext; typed::Bool = false)
    pushVarScope(ctx)
    st = typed ? 3 : 2
    fn = typed ? 2 : 1

    if typed
        if ex.head == :typed_dict_comprehension
            if isexpr(ex.args[1], :(=>))
                declktype = ex.args[1].args[1]
                declvtype = ex.args[1].args[2]
                if declktype == TopNode(:Any) && declvtype == TopNode(:Any) && VERSION < v"0.4-"
                    msg(ctx, :I484, "untyped dictionary {a=>b for (a,b) in c}, may " *
                        "be deprecated by Julia 0.4. Use (Any=>Any)[a=>b for (a,b) in c]")
                end
            end
        else
            declvtype = ex.args[1]
            if declvtype == TopNode(:Any) && VERSION < v"0.4-"
                msg(ctx, :I485, "untyped dictionary {a for a in c}, may be " *
                    "deprecated by Julia 0.4. Use (Any)[a for a in c].")
            end
        end
    end

    for i in st:length(ex.args)
        if isexpr(ex.args[i], :(=))
            lintassignment(ex.args[i], :(=), ctx; islocal=true, isForLoop=true) # note contrast with for loop
        end
    end
    lintexpr(ex.args[fn], ctx)
    popVarScope(ctx)
end
