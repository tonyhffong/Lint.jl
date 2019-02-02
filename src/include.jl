"""
Include a file to your lintContext.
If file does not exist or has already been included, raise a lint warning.
"""
function lintinclude(ctx::LintContext, f::AbstractString)
    if ispath(f)
        # TODO: use paths instead of files
        if f in ctx.included
            msg(ctx, :W356, f, "file included more than once")
        else
            push!(ctx.included, f)
        end

        oldloc = location(ctx)
        str = read(f, String)
        location!(ctx, Location(f, 1))

        # TODO: make sure to perform the include at top level
        _lintstr(str, ctx)

        location!(ctx, oldloc)
    else
        msg(ctx, :W357, f, "included file doesn't exist")
    end
end
