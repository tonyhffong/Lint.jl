module ExpressionIterator
"""Iterator of Substrings on which each contains a line"""
each_line_iterator(s::AbstractString) = Channel(c->begin
            for substring in split(s, "\n", limit=0, keepempty=false)
                put!(c, substring)
            end
            end, ctype=SubString{String})

struct EachExpression
    original::String
    current_line_offset::Int # used externally
end

""" Get [begin, end] offsets for each line (end is inclusive)"""
lines_offsets(s::AbstractString) = map(line->begin
                                       real_offset=line.offset +1 # SubString.offset + 1 ↔ String.index
                                       (real_offset, real_offset + length(line) -1) # TODO(felipe) use `prevind` ?
                                       end, each_line_iterator(s))

"""points to info about "where should we get our *next* expression"""
struct _EachExpressionState
    next_line_offset # `iterate(lines_offsets(…))`
    offset_where_last_expression_ends::Union{Nothing,Int}
end

_EachExpressionState(iter::EachExpression) = _EachExpressionState(
    Base.iterate(lines_offsets(iter.original)),
    nothing)

function Base.iterate(iter::EachExpression, state=_EachExpressionState(iter)) #::Union{Nothing, Tuple{EachExpression, _EachExpressionState}}
    if state.line_offset_it == nothing
        # no more lines → we're done
        return nothing
    end

    # line ↔ [begin, end] offsets that describe a line

    # move next-line-wards …
    (current_line, current_line_state) = state.line_offset_it
    @show state.line_offset_it, current_line
    (line_begin, line_end) = current_line
    next_line_it = iterate(state.line_offset_it, current_line_state)

    # … at least we catch up with last parsed expression
    if state.offset_where_last_expression_ends !== nothing
        while line_begin < state.offset_where_last_expression_ends
            if next_line_it isa Nothing
                # ran out of lines with the last expression → nothing left to parse
                return nothing
            end
            # update current line info
            (current_line, current_line_state) = next_line_it
            (line_begin, line_end) = current_line

            # update next line info
            next_line_it = iterate(next_line_it, current_line_state)
            @show current_line, next_line_it
        end
    end

    @show line_begin, line_end
    @show "trying to parse ", SubString(iter.original, line_begin, line_end)
    (ex, i_for_end_of_expression) = Meta.parse(iter.original, line_begin)

    return (ex, _EachExpressionState(next_line_it,
                                     i_for_end_of_expression))
end

each_expression(original::String, current_line_offset=0) = EachExpression(original, current_line_offset)

function Base.length(iter::EachExpression)
    count=0
    for ex in iter
        count += 1
    end
    count
end

end # module ExpressionIterator
