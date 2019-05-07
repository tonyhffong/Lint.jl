module ExpressionIterator
"""Iterator of Substrings on which each contains a line"""
each_line_iterator(s::AbstractString) = Channel(c->begin
            for substring in split(s, "\n", limit=0, keepempty=false)
                put!(c, substring)
            end
            end, ctype=SubString{String})

struct EachExpressionAndOffset
    original::String
    next_line_offset_it # `lines_offsets(…)`
end

""" Get [begin, end] offsets for each line (end is inclusive)"""
lines_offsets(s::AbstractString) = map(line->begin
                                       real_offset=line.offset +1 # SubString.offset + 1 ↔ String.index
                                       (real_offset, real_offset + length(line) -1) # TODO(felipe) use `prevind` ?
                                       end, each_line_iterator(s))

"""points to info about "where should we get our *next* expression"""
struct _EachExpressionAndOffsetState
    maybe_next_line_offset # as in ` = iterate(…)`
    offset_where_last_expression_ends::Union{Nothing,Int}
end

_EachExpressionAndOffsetState(iter::EachExpressionAndOffset) = _EachExpressionAndOffsetState(
    Base.iterate(iter.next_line_offset_it),
    nothing)

function Base.iterate(iter::EachExpressionAndOffset, state=_EachExpressionAndOffsetState(iter)) #::Union{Nothing, Tuple{EachExpressionAndOffset, _EachExpressionAndOffsetState}}
    if state.maybe_next_line_offset ≡ nothing
        # no more lines → we're done
        return nothing
    end

    # line ↔ [begin, end] offsets that describe a line

    # move next-line-wards …
    (current_line, current_line_state) = state.maybe_next_line_offset
    (line_begin, line_end) = current_line
    maybe_next_line = Base.iterate(iter.next_line_offset_it, current_line_state)

    # … at least we catch up with last parsed expression
    if state.offset_where_last_expression_ends !== nothing
        while line_begin < state.offset_where_last_expression_ends
            if maybe_next_line isa Nothing
                # ran out of lines with the last expression → nothing left to parse
                return nothing
            end
            # update current line info
            (current_line, current_line_state) = maybe_next_line
            (line_begin, line_end) = current_line

            # update next line info
            maybe_next_line = Base.iterate(iter.next_line_offset_it, current_line_state)
        end
    end

    (ex, i_for_end_of_expression) = Meta.parse(iter.original, line_begin)
    iter_value=(ex, line_begin, line_end)
    iter_state=_EachExpressionAndOffsetState(maybe_next_line,
                                     i_for_end_of_expression)
    return (iter_value, iter_state)
end

each_expression_and_offset(original::AbstractString) = EachExpressionAndOffset(original, lines_offsets(original))

function Base.length(iter::EachExpressionAndOffset)
    count=0
    for ex in iter
        count += 1
    end
    count
end

each_expression(original::AbstractString) = map(ex_off->begin
                                                (ex, line_begin, line_end) = ex_off
                                                ex
                                                end, each_expression_and_offset(original))





end # module ExpressionIterator
