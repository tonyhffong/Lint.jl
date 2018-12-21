module ExpressionIterator
"""Iterator of Substrings on which each contains a line"""
each_line_iterator(s::AbstractString) = split(s, "\n", limit=0, keepempty=false)

end # module ExpressionIterator
