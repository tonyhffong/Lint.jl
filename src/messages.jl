function Base.show(io::IO, m::LintMessage)
    s = string(location(m), " ", m.code, " ", m.variable, ": ")
    print(io, s)
    ident = min(60, length(s))
    lines = split(m.message, "\n")
    print(io, lines[1])
    for l in lines[2:end]
        print(io, "\n", " " ^ ident, l)
    end
end

function Base.isless(m1::LintMessage, m2::LintMessage)
    if file(m1) != file(m2)
        return isless(file(m1), file(m2))
    end
    if level(m1) != level(m2)
        # ERROR < WARN < INFO
        return iserror(m1) || isinfo(m2)
    end
    if line(m1) != line(m2)
        return line(m1) < line(m2)
    end
    if m1.code != m2.code
        return m1.code < m2.code
    end
    if m1.variable != m2.variable
        return m1.variable < m2.variable
    end
    return m1.message < m2.message
end

function msg(ctx::LintContext, code::Symbol, variable, str::AbstractString)
    variable = string(variable)
    m = LintMessage(location(ctx), code, ctx.scope, variable, str)
    # filter out messages to ignore
    i = findfirst(ctx.ignore, LintIgnore(code, variable))
    if i == 0
        push!(ctx.messages, m)
    else
        push!(ctx.ignore[i].messages, m)
    end
end

function msg(ctx::LintContext, code::Symbol, str::AbstractString)
    msg(ctx, code, "", str)
end

iserror(m::LintMessage) = string(m.code)[1] == 'E'
iswarning(m::LintMessage) = string(m.code)[1] == 'W'
isinfo(m::LintMessage) = string(m.code)[1] == 'I'

const ERRORLEVELS = Dict{Char, Symbol}('E'=>:ERROR, 'W'=>:WARN, 'I'=>:INFO)
level(m::LintMessage) = ERRORLEVELS[string(m.code)[1]]

"Process messages. Sort and remove duplicates."
function clean_messages!(msgs::Array{LintMessage, 1})
    sort!(msgs)
    delids = Int[]
    for i in 2:length(msgs)
        if  msgs[i] == msgs[i-1]
            push!(delids, i)
        end
    end
    deleteat!(msgs, delids)
end
