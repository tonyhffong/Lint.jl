const LINT_RESULT_COLORS = Dict(
    :INFO => :bold,
    :WARN => :yellow,
    :ERROR => :magenta,
    :OK => :green)

"""
A collection of `LintMessage`s. This behaves similarly to a vector of
`LintMessage`s, but has different display behaviour.
"""
immutable LintResult <: AbstractVector{LintMessage}
    messages::Array{LintMessage, 1}
end

function Base.show(io::IO, res::LintResult)
    print(io, "LintResult(")
    show(io, res.messages)
    print(io, ")")
end
function Base.show(io::IO, ::MIME"text/plain", res::LintResult)
    for m in res.messages
        Base.println_with_color(LINT_RESULT_COLORS[level(m)], io, string(m))
    end
end

Base.length(r::LintResult) = length(r.messages)
Base.size(r::LintResult) = size(r.messages)
Base.isempty(r::LintResult) = isempty(r.messages)
Base.start(r::LintResult) = start(r.messages)
Base.done(r::LintResult, s) = done(r.messages, s)
Base.next(r::LintResult, s) = next(r.messages, s)

# delegate getindex to parent collection
Base.getindex(r::LintResult, i...) = r.messages[i...]

# this function is useful for filtering on severity level
Base.filter(p, r::LintResult) = LintResult(filter(p, r.messages))
