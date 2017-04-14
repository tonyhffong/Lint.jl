function lintgenerator(ex::Expr, ctx::LintContext; typed::Bool = false)
    # TODO: use a new variable scope
    st = typed ? 3 : 2
    fn = typed ? 2 : 1

    # TODO: Use declared type information.
    for i in st:length(ex.args)
        if isexpr(ex.args[i], :(=))
            lintassignment(ex.args[i], :(=), ctx; islocal=true, isForLoop=true) # note contrast with for loop
        end
    end
    lintexpr(ex.args[fn], ctx)
end
