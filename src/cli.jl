include("expression_iterator.jl")
using Compat
function lintpkg(pkg::AbstractString)
    if occursin("/", pkg) # pkg is a file path
        return LintResult(lintpkgforfile(pkg))
    end

    try
        p = Base.find_package(pkg)
        LintResult(lintpkgforfile(p))
    catch
        throw("cannot find package: " * pkg)
    end
end

"""
Lint the package for a file.
If file is in src, lint Package.jl and its includes.
If file is in test, lint runtests.jl and its includes.
If file is in base lint all files in base dir.
"""
function lintpkgforfile(path::AbstractString, ctx::LintContext=LintContext())
    path = abspath(path)
    if ispath(ctx.path)
        if Sys.iswindows()
            len = count(x -> x == '\\', path)
        else
            len = count(x -> x == '/', path) - 1
        end
        for _ = 1:len
            path, folder = splitdir(path)
            if folder == "src"
                file = joinpath(path, folder, basename(path) * ".jl")
                if ispath(file)
                    lintinclude(ctx, file)
                end
                break
            elseif folder == "test"
                file = joinpath(path, folder, "runtests.jl")
                if ispath(file)
                    lintinclude(ctx, file)
                end
                break
            elseif folder == "base"
                lintdir(joinpath(path, folder), ctx)
                break
            end
        end
    end
    finish(ctx)
    ctx.messages
end

function lintfile(f::AbstractString)
    if !ispath(f)
        throw("no such file exists")
    end
    str = open(readstring, f)
    lintfile(f, str)
end

function lintfile(f::AbstractString, code::AbstractString)
    ctx = LintContext(f)

    _lintstr(code, ctx)
    finish(ctx)
    msgs = ctx.messages

    # If we have an undeclared symbol, lint the package to try and resolve
    for message in msgs
        if message.code == :E321 # undeclared symbol
            ctx = LintContext(f)
            message = lintpkgforfile(file(ctx), ctx)
            break
        end
    end

    filter!(msg -> file(msg) == f, msgs)
    sort!(msgs)

    LintResult(msgs)
end

"Produce expressions to channel from full_string according to current_line."
function _produce_expressions(channel, context, full_string, current_line_offset, current_line)
    try
        # `i` will be sliding index of start-for-current-expression
        i = current_line_offset
        while i ≤ length(current_line)
            (ex, i_for_end_of_expression) = Meta.parse(full_string, i)
            put!(channel, (ex, i_for_end_of_expression)) # also report end-of-expression to avoid double parsing
            # update for next loop
            i = i_for_end_of_expression
        end
    catch y
        # report an unexpected error
        # end-of-input and parsing errors are expected
        if typeof(y) != Meta.ParseError || y.msg != "end of input"
            msg(context, :E111, string(y))
        end
    end
    nothing
end

"Lint over each expression in each line.

Calls `lintexpr` over each parseable-parsed expression.
Each parse is called over each line."
function _lintstr(str::AbstractString, ctx::LintContext, lineoffset = 0)
    non_empty_lines=split(str, "\n", limit=0, keepempty=false)
    offset_where_last_expression_ends=nothing
    for line in non_empty_lines
        current_line_offset=line.offset + 1 # SubString.offset + 1 ↔ String.index
        if (offset_where_last_expression_ends !== nothing
            && current_line_offset < offset_where_last_expression_ends)
            # line was already parsed
            continue
        end

        # inform context of current line
        ctx.line = ctx.lineabs = (current_line_offset + length(line)) + lineoffset

        expr_ch = Channel(c->_produce_expressions(c, ctx, str, current_line_offset, line))
        # lint/consume expressions
        for (ex,offset_where_expression_ends) in expr_ch
            lintexpr(ex, ctx)
            offset_where_last_expression_ends=offset_where_expression_ends
        end
    end
end

"""
    lintstr(s::AbstractString)

Unlike other lint functions, like `lintpkg` and `lintfile`, `lintstr` does not
ignore any messages by default.
"""
function lintstr(str::AbstractString,
                 ctx::LintContext = (c = LintContext(); c.ignore = []; c))
    _lintstr(str, ctx)
    finish(ctx)
    ctx.messages
end

"""
Lint all .jl ending files at a given directory.
Will ignore LintContext file and already included files.
"""
function lintdir(dir::AbstractString, ctx::LintContext=LintContext())
    for file in readdir(dir)
        if endswith(file, ".jl")
            file = joinpath(dir, file)
            if !isdir(file)
                lintinclude(ctx, file)
            end
        end
    end
    finish(ctx)
    ctx.messages
end
