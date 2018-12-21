macro checktoplevel(ctx, expr)
    quote
        if !istoplevel($(esc(ctx)).current)
            msg($(esc(ctx)), :E100, "$($(esc(expr))) expression must be at top level")
            return
        end
    end
end

macro checkisa(ctx, var, typ)
    quote
        if !isa($(esc(var)), $(esc(typ)))
            msg($(esc(ctx)), :E101, $(esc(var)), "this expression must be a $($(esc(typ)))")
            return
        end
    end
end

function lintexpr(ex::Symbol, ctx::LintContext)
    registersymboluse(ex, ctx)
end

function lintexpr(ex::QuoteNode, ctx::LintContext)
    if typeof(ex.value) == Expr
        ctx.quoteLvl += 1
        lintexpr(ex.value, ctx)
        ctx.quoteLvl -= 1
    end
end

function lintexpr(ex::Expr, ctx::LintContext)
    # TODO: reenable linthelpers
    if ex.head == :line
        # ignore line numer nodes
        return
    elseif ex.head == :block
        lintblock(ex, ctx)
    elseif ex.head == :quote
        ctx.quoteLvl += 1
        lintexpr(ex.args[1], ctx)
        ctx.quoteLvl -= 1
    elseif ex.head == :if
        lintifexpr(ex, ctx)
    elseif ex.head == :(=) && typeof(ex.args[1])==Expr && ex.args[1].head == :call
        lintfunction(ex, ctx)
    elseif expand_assignment(ex) !== nothing
        ea = expand_assignment(ex)
        lintassignment(Expr(:(=), ea[1], ea[2]), ctx)
    elseif ex.head == :local
        lintlocal(ex, ctx)
    elseif ex.head == :global
        lintglobal(ex, ctx)
    elseif ex.head == :const
        if typeof(ex.args[1]) == Expr && ex.args[1].head == :(=)
            lintassignment(ex.args[1], ctx; isConst = true)
        end
    elseif ex.head == :module
        lintmodule(ex, ctx)
    elseif ex.head == :export
        lintexport(ex, ctx)
    elseif isexpr(ex, [:import, :using, :importall])
        lintimport(ex, ctx)
    elseif ex.head == :comparison # only the odd indices
        for i in 1:2:length(ex.args)
            # comparison like match != 0:-1 is allowed, and shouldn't trigger lint warnings
            if Meta.isexpr(ex.args[i], :(:)) && length(ex.args[i].args) == 2 &&
                typeof(ex.args[i].args[1]) <: Real &&
                typeof(ex.args[i].args[2]) <: Real
                continue
            else
                lintexpr(ex.args[i], ctx)
            end
        end
        lintcomparison(ex, ctx)
    elseif ex.head == :type
        linttype(ex, ctx)
    elseif ex.head == :typealias
        # TODO: deal with X{T} = Y assignments, also const X = Y
        linttypealias(ex, ctx)
    elseif ex.head == :abstract
        lintabstract(ex, ctx)
    elseif ex.head == :bitstype
        lintbitstype(ex, ctx)
    elseif ex.head == :(->)
        lintlambda(ex, ctx)
    elseif ex.head == :($) && ctx.quoteLvl > 0 # an unquoted node inside a quote node
        ctx.quoteLvl -= 1
        lintexpr(ex.args[1], ctx)
        ctx.quoteLvl += 1
    elseif ex.head == :function
        lintfunction(ex, ctx)
    elseif ex.head == :stagedfunction
        lintfunction(ex, ctx, isstaged=true)
    elseif ex.head == :macrocall && ex.args[1] == Symbol("@generated")
        lintfunction(ex.args[2], ctx, isstaged=true)
    elseif ex.head == :macro
        lintmacro(ex, ctx)
    elseif ex.head == :macrocall
        lintmacrocall(ex, ctx)
    elseif ex.head == :call
        lintfunctioncall(ex, ctx)
    elseif ex.head == :(:)
        lintrange(ex, ctx)
    elseif ex.head == :(::) # type assert/convert
        lintexpr(ex.args[1], ctx)
    elseif ex.head == :(.) # a.b
        lintexpr(ex.args[1], ctx)
    elseif ex.head == :ref # it could be a ref a[b], or an array Int[1,2]
        lintref(ex, ctx)
    elseif ex.head == :typed_vcat# it could be a ref a[b], or an array Int[1,2]
        linttyped_vcat(ex, ctx)
    elseif ex.head == :vcat
        lintvcat(ex, ctx)
    elseif ex.head == :vect # 0.4
        lintvect(ex, ctx)
    elseif ex.head == :hcat
        linthcat(ex, ctx)
    elseif ex.head == :typed_hcat
        linttyped_hcat(ex, ctx)
    elseif ex.head == :cell1d
        lintcell1d(ex, ctx)
    elseif ex.head == :while
        lintwhile(ex, ctx)
    elseif ex.head == :for
        lintfor(ex, ctx)
    elseif ex.head == :let
        lintlet(ex, ctx)
    elseif ex.head in (:comprehension, :dict_comprehension, :generator)
        lintgenerator(ex, ctx; typed = false)
    elseif ex.head in (:typed_comprehension, :typed_dict_comprehension)
        lintgenerator(ex, ctx; typed = true)
    elseif ex.head == :try
        linttry(ex, ctx)
    elseif ex.head == :curly # e.g. Ptr{T}
        lintcurly(ex, ctx)
    elseif ex.head in [:(&&), :(||)]
        lintboolean(ex.args[1], ctx)
        lintexpr(ex.args[2], ctx) # do not enforce boolean. e.g. b==1 || error("b must be 1!")
    elseif ex.head == :incomplete
        msg(ctx, :E112, ex.args[1])
    else
        for sube in ex.args
            lintexpr(sube, ctx)
        end
    end
end

# no-op fallback for other kinds of expressions (e.g. LineNumberNode) that we
# don’t care to handle
lintexpr(::Any, ::LintContext) = return
