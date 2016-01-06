function Base.show(io::IO, m::LintMessage)
    s = @sprintf("%s:%d ", m.file, m.line)
    s *= @sprintf("%s ", m.code)
    s *= @sprintf("%s: ", m.variable)
    print(io, s)
    ident = min(60, length(s))
    lines = split(m.message, "\n")
    print(io, lines[1])
    for l in lines[2:end]
        print(io, "\n", " " ^ ident, l)
    end
end

function ==(m1::LintMessage, m2::LintMessage)
    m1.file == m2.file &&
    m1.code == m2.code &&
    m1.scope == m2.scope &&
    m1.line == m2.line &&
    m1.variable == m2.variable &&
    m1.message == m2.message
end

function Base.isless(m1::LintMessage, m2::LintMessage)
    if m1.file != m2.file
        return isless(m1.file, m2.file)
    end
    if level(m1) != level(m2)
        # ERROR < WARN < INFO
        return iserror(m1) || isinfo(m2)
    end
    if m1.line != m2.line
        return m1.line < m2.line
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
    m = LintMessage(ctx.file, code, ctx.scope, ctx.lineabs + ctx.line, variable, str)
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
function clean_messages!(msgs::Array{LintMessage})
    sort!(msgs)
    delids = Int[]
    for i in 2:length(msgs)
        if  msgs[i] == msgs[i-1]
            push!(delids, i)
        end
    end
    deleteat!(msgs, delids)
end

function display_messages(msgs::Array{LintMessage})
    colors = Dict{Symbol, Symbol}(:INFO => :bold, :WARN => :yellow, :ERROR => :magenta)
    for m in msgs
        Base.println_with_color(colors[level(m)], string(m))
    end
end
