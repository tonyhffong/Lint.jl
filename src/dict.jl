function lintdict(ex::Expr, ctx::LintContext)
    typed = isexpr(ex.args[1], :curly)
    st = 2
    ks = Set{Any}()
    ktypes = Set{Any}()
    vtypes = Set{Any}()
    for i in st:length(ex.args)
        a = ex.args[i]
        if typeof(a) == Expr && a.head == :(=>)
            if typeof(a.args[1]) != Expr
                if in(a.args[1], ks)
                    msg(ctx, :E334, a.args[1], "duplicate key in Dict")
                end
                push!(ks, a.args[1])
            end
            for (j,s) in [(1,ktypes), (2,vtypes)]
                if typeof(a.args[j]) <: QuoteNode && typeof(a.args[j].value) <: Symbol
                    push!(s, Symbol)
                elseif typeof(a.args[j]) <: Number || typeof(a.args[j]) <: AbstractString
                    push!(s, typeof(a.args[j]))
                    # we want to add more immutable types such as Date, DateTime, etc.
                elseif isexpr(a.args[j], :call) && in(a.args[j].args[1], [:Date, :DateTime])
                    push!(s, a.args[j].args[1])
                else
                    if typed
                        push!(s, Any)
                    end
                end
            end
        end

        lintexpr(a, ctx)
    end

    if typed
        if length(ktypes) > 1 && ex.args[1].args[2] != :Any && !isexpr(ex.args[1].args[2], :call)
            msg(ctx, :E531, "multiple key types detected. Use Dict{Any,V}() for mixed type dict")
        end
        if length(vtypes) > 1 && ex.args[1].args[3] != :Any && !isexpr(ex.args[1].args[3], :call)
            msg(ctx, :E532, "multiple value types detected. Use Dict{K,Any}() for mixed type dict")
        end
    end
end
