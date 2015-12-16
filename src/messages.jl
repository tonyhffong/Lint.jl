function Base.string(m::LintMessage)
    s = @sprintf("%s:%d ", m.file, m.line)
    s = s * @sprintf("%s%s ", string(m.level)[1], m.code)
    s = s * @sprintf("%s: ", m.variable)
    ident = min(60, length(s))
    lines = split(m.message, "\n")
    for (i,l) in enumerate(lines)
        if i==1
            s = s * l
        else
            s = s * "\n" *  (" " ^ ident) * l
        end
    end
    return s
end

function ==(m1::LintMessage, m2::LintMessage)
    m1.file == m2.file &&
    m1.level == m2.level &&
    m1.code == m2.code &&
    m1.scope == m2.scope &&
    m1.line == m2.line &&
    m1.variable == m2.variable &&
    m1.message == m2.message
end

function Base.show(io::IO, m::LintMessage)
    print(io, string(m))
end

function Base.isless(m1::LintMessage, m2::LintMessage)
    if m1.file != m2.file
        return isless(m1.file, m2.file)
    end
    if m1.level != m2.level
        return m1.level == :ERROR || m2.level == :INFO
    end
    if m1.line != m2.line
        return m1.line < m2.line
    end
    if m1.code != m2.code
        return m1.code < m2.code
    end
    return m1.message < m2.message
end

function msg(ctx::LintContext, level::Symbol, code::Int, variable, str::AbstractString)
    variable = string(variable)
    m = LintMessage(ctx.file, level, code, ctx.scope, ctx.lineabs + ctx.line, variable, str)
    i = findfirst(ctx.ignore, LintIgnore(Symbol(string(string(level)[1], code)), variable))
    if i == 0
        push!(ctx.messages, m)
    else
        push!(ctx.ignore[i].messages, m)
    end
end

function msg(ctx::LintContext, level::Symbol, code::Int, str::AbstractString)
    msg(ctx, level, code, "", str)
end

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
        Base.println_with_color(colors[m.level], string(m))
    end
end