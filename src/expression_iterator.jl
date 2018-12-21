module ExpressionIterator
"""Iterator of Substrings on which each contains a line"""
function each_line_iterator(s::AbstractString)
    Channel(c->begin
            for substring in split(s, "\n", limit=0, keepempty=false)
                put!(c, substring)
            end
            end, ctype=SubString{String})
end

struct EachExpression
    original::String
    current_line_offset::Int
end

struct _EachExpressionState
    next_line_it # `iterate(each_line_iterator(…))`
    offset_where_last_expression_ends::Union{Int,Nothing}
end
_EachExpressionState(iter::EachExpression) = _EachExpressionState(
    Base.iterate(each_line_iterator(iter.original)),
    nothing)

offset_lines(s::AbstractString) = map(line->begin
                                      (line, line.offset +1) # SubString.offset + 1 ↔ String.index
                                      end, each_line_iterator(s))

function Base.iterate(iter::EachExpression, state=_EachExpressionState(iter)) #::Union{Nothing, Tuple{EachExpression, _EachExpressionState}}
    if state.next_line !== nothing
        # no more lines → we're done
        return nothing
    end

    (line_it, line_state) = state.next_line_it
    current_line_offset=line.offset + 1
    next_line = line_it
    if offset_where_last_expression_ends !== nothing
        # move line-ward forward until we catch up with last parsed expression
        while current_line_offset < offset_where_last_expression_ends
            if next_line isa Nothing
                # ran out of lines with the last expression
                return nothing
            end
            next_line = iterate(line_it, line_state)
        end
    end

    try
        # `i` will be sliding index of start-for-current-expression
        i = iter.current_line_offset
        while i ≤ length(current_line)
            (ex, i_for_end_of_expression) = Meta.parse(full_string, i)
            return (ex, _EachExpressionState(next_line, i_for_end_of_expression))
        end
    catch y
        # report an unexpected error
        # end-of-input and parsing errors are expected
        if typeof(y) != Meta.ParseError || y.msg != "end of input"
            msg(context, :E111, string(y))
        end
    end
end

each_expression(original::String, current_line_offset=0) = EachExpression(original, current_line_offset)

end # module ExpressionIterator
