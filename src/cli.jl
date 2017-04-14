function lintpkg(pkg::AbstractString)
    p = joinpath(Pkg.dir(pkg), "src", basename(pkg) * ".jl")
    if !ispath(p)
        throw("cannot find path: " * p)
    end
    LintResult(lintpkgforfile(p))
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
        if is_windows()
            len = count(x -> x == '\\', path)
        else
            len = count(x -> x == '/', path) - 1
        end
        for i = 1:len
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

    msgs = lintstr(code, ctx)

    # If we have an undeclared symbol, lint the package to try and resolve
    for message in msgs
        if message.code == :E321 # undeclared symbol
            ctx = LintContext(f)
            message = lintpkgforfile(file(ctx), ctx)
            break
        end
    end

    filter!(msg -> file(msg) == f, msgs)
    clean_messages!(msgs)

    LintResult(msgs)
end

function lintstr(str::AbstractString, ctx::LintContext = LintContext(), lineoffset = 0)
    linecharc = cumsum(map(x->endof(x)+1, split(str, "\n", keep=true)))
    numlines = length(linecharc)
    i = start(str)
    while !done(str,i)
        problem = false
        ex = nothing
        linerange = searchsorted(linecharc, i)
        if linerange.start > numlines # why is it not donw?
            break
        else
            linebreakloc = linecharc[linerange.start]
        end
        if linebreakloc == i || isempty(strip(str[i:(linebreakloc-1)]))# empty line
            i = linebreakloc + 1
            continue
        end
        ctx.lineabs = linerange.start + lineoffset
        try
            (ex, i) = parse(str,i)
        catch y
            if typeof(y) != ParseError || y.msg != "end of input"
                msg(ctx, :E111, string(y))
            end
            problem = true
        end
        if !problem
            ctx.line = 0
            lintexpr(ex, ctx)
        else
            break
        end
    end
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
