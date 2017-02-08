function lintlintpragma(ex::Expr, ctx::LintContext)
    if length(ex.args) >= 2 && isa(ex.args[2], AbstractString)
        m = match(r"^((Print)|(Info)|(Warn)|(Error)) ((type)|(me)|(version)) +(.+)"s, ex.args[2])
        if m != nothing
            action = m.captures[1]
            infotype = m.captures[6]
            rest_str = m.captures[10]
            if infotype == "type"
                v = parse(rest_str)
                if isexpr(v, :incomplete)
                    msg(ctx, :E138, rest_str, "incomplete pragma expression")
                    str = ""
                else
                    str = "typeof($rest_str) == $(guesstype(v, ctx))"
                end
            elseif infotype == "me"
                str = rest_str
            elseif infotype == "version"
                v = convert(VersionNumber, rest_str)
                reachable = ctx.versionreachable(v)
                if reachable
                    str = "Reachable by " * string(v)
                else
                    str = "Unreachable by " * string(v)
                end
            end

            if action == "Print"
                println(str)
            elseif action == "Info"
                msg(ctx, :I271, str)
            elseif action == "Warn"
                msg(ctx, :W241, str)
            else
                msg(ctx, :E221, str)
            end
        else
            if !ctx.versionreachable(VERSION)
                return
            end
            ctx.callstack[end].pragmas[ex.args[2]] = PragmaInfo(ctx.line, false)
        end
    else
        msg(ctx, :E137, "lintpragma must be called using only string literals")
    end
end

function pragmaexists(s::Compat.UTF8String, ctx::LintContext; deep=true)
    iend = deep ? 1 : length(ctx.callstack)
    for i in length(ctx.callstack):-1:iend
        if haskey(ctx.callstack[i].pragmas, s)
            ctx.callstack[i].pragmas[s].used = true # it has been used
            return true
        end
    end
    return false
end

pragmaexists(s::AbstractString, ctx::LintContext; deep = true) = pragmaexists(Compat.UTF8String(s), ctx; deep = deep)
