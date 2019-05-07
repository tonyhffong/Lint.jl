function lintblock(ex::Expr, ctx::LintContext)
    lastexpr = nothing
    similarexprs = Expr[]
    diffs = Float64[]
    checksimilarityflag = !(LintIgnore(:W651, "") in ctx.ignore)

    if checksimilarityflag
        checksimilarity = ()->begin
            if length(similarexprs) <= 2 # not much I can do
                diffs = Float64[]
                lastexpr = nothing
                similarexprs = Expr[]
            else
                # cyclic diffs, so now we have at least 3 similarity scores
                push!(diffs, expr_similar_score(similarexprs[1], similarexprs[end]))
                local n = length(diffs)
                local m = mean(diffs)
                local s = std(diffs)
                local m2 = mean([diffs[end-1], diffs[end]])
                # look for screw up at the end
                #println(diffs, "\nm=", m, " s=", s, " m2=", m2, " m-m2=", m-m2)
                if m2 < m && m-m2 > s/2.5 && s / m > 0.0001
                    msg(ctx, :W651, "the last of a $(n)-expr block looks different" *
                        ";  Avg similarity score: " * @sprintf("%8.2f", m) *
                        ";  Last part: " * @sprintf("%9.2f", m2))
                end
                diffs = Float64[]
                lastexpr = nothing
                similarexprs = Expr[]
            end
        end
    end

    for (i,sube) in enumerate(ex.args)
        if isa(sube, Expr)
            if sube.head == :line
                ctx.line = ctx.lineabs + sube.args[1]-1
                continue
            elseif sube.head == :return && i != length(ex.args)
                msg(ctx, :W641, "unreachable code after return")
                lintexpr(sube, ctx)
                break
            else
                if checksimilarityflag
                    if lastexpr != nothing
                        local dif = expr_similar_score(lastexpr, sube)
                        if dif > SIMILARITY_THRESHOLD
                            if !isempty(similarexprs)
                                append!(similarexprs, [lastexpr, sube])
                            else
                                push!(similarexprs, sube)
                            end
                            push!(diffs, dif)
                        else
                            checksimilarity()
                        end
                    end
                end
                lintexpr(sube, ctx)
                lastexpr = sube
            end
        elseif isa(sube, QuoteNode)
            lintexpr(sube,ctx)
        elseif isa(sube, LineNumberNode)
            ctx.line = ctx.lineabs + sube.line-1
            continue
        elseif isa(sube, Symbol)
            registersymboluse(sube, ctx)
            if checksimilarityflag
                checksimilarity()
            end
        end
    end

    if checksimilarityflag
        checksimilarity()
    end
end

function expr_similar_score(e1::Expr, e2::Expr, base::Float64 = 1.0)
    if e1.head != e2.head
        return -base
    end

    score = base - abs(length(e1.args) - length(e2.args)) * base * 2.0

    for i in 1:min(length(e1.args), length(e2.args))
        if typeof(e1.args[i]) == Expr && typeof(e2.args[i]) == Expr
            score += expr_similar_score(e1.args[i], e2.args[i], base * 1.1)
        elseif typeof(e1.args[i]) == typeof(e2.args[i])
            score += base * 0.3
            if e1.args[i] == e2.args[i]
                score += base * 0.8
            end
        else
            score -= base
        end
        if score < 0.0 # so early disagreement dominates and short-circuit
            break
        end
    end
    return score
end

function test_similarity_string(str::T) where T<:AbstractString
    i = start(str)
    firstexpr = nothing
    lastexpr = nothing
    diffs = Float64[]
    while !done(str,i)
        problem = false
        ex = nothing
        try
            (ex, i) = parse(str,i)
        catch
            problem = true
        end
        if !problem
            if firstexpr ≡ nothing
                firstexpr = ex
            end
            if lastexpr != nothing
                push!(diffs, expr_similar_score(lastexpr, ex))
            end
            lastexpr = ex
        else
            break
        end
    end
    if lastexpr != nothing && length(diffs) >= 2
        push!(diffs, expr_similar_score(lastexpr, firstexpr))
    end
    return diffs
end

function linttry(ex::Expr, ctx::LintContext)
    # try
    withcontext(ctx, LocalContext(ctx.current)) do
        lintexpr(ex.args[1], ctx)
    end

    # catch
    if isa(ex.args[2], Symbol)
        withcontext(ctx, LocalContext(ctx.current)) do
            set!(ctx.current, ex.args[2], VarInfo(location(ctx), Exception))
            lintexpr(ex.args[3], ctx)
        end
    end

    # finally
    if length(ex.args) > 3
        @assert length(ex.args) == 4
        withcontext(ctx, LocalContext(ctx.current)) do
            lintexpr(ex.args[4], ctx)
        end
    end
end

function lintlet(ex::Expr, ctx::LintContext)
    withcontext(ctx, LocalContext(ctx.current)) do
        for arg in ex.args
            # it's always assignment, or the parser would have thrown at the very start
            if isexpr(arg, :(=)) && !isexpr(arg.args[1], :call)
                lintassignment(arg, ctx; islocal = true)
            end
        end
        blk = ex.args[1]
        @assert isexpr(blk, :block)
        for arg in blk.args
            if isexpr(arg, :(=)) && !isexpr(arg.args[1], :call)
                lintassignment(arg, ctx; islocal = true)
            else
                lintexpr(arg, ctx)
            end
        end
    end
end
