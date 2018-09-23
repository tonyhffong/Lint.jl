# TODO: when 0.5 support dropped, remove the isdefined check
const LINT_RESULT_COLORS = Dict(
    :INFO => Base.info_color(),
    :WARN => Base.warn_color(),
    :ERROR => isdefined(Base, :error_color) ? Base.error_color() :
                                              Base.warn_color(),
    :OK => :green)

"""
A collection of `LintMessage`s. This behaves similarly to a vector of
`LintMessage`s, but has different display behaviour.
"""
struct LintResult <: AbstractVector{LintMessage}
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

Base.size(r::LintResult) = size(r.messages)

# delegate getindex to parent collection
Base.getindex(r::LintResult, i::Int) = r.messages[i]

# this function is useful for filtering on severity level
Base.filter(p, r::LintResult) = LintResult(filter(p, r.messages))
