function lintdict(ex::Expr, ctx::LintContext)
    typed = isexpr(ex.args[1], :curly)
    ks = Set{Any}()
    ktypes = Set{Any}()
    vtypes = Set{Any}()
    for a in ex.args[2:end]
        if ispairexpr(a)
            keyexpr = lexicalfirst(a)
            lit = lexicalvalue(keyexpr)
            if !isnull(lit)
                if keyexpr in ks
                    msg(ctx, :E334, keyexpr, "duplicate key in Dict")
                end
                push!(ks, keyexpr)
            end
            for (j,s) in [(lexicalfirst,ktypes), (lexicallast,vtypes)]
                kvexpr = j(a)
                typeguess = lexicaltypeof(kvexpr)
                if isconcretetype(typeguess)
                    push!(s, typeguess)
                elseif isexpr(kvexpr, :call) && in(kvexpr.args[1], [:Date, :DateTime])
                    # TODO: use the existing guesstype infrastructure
                    # we want to add more immutable types such as Date, DateTime, etc.
                    push!(s, kvexpr.args[1])
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
