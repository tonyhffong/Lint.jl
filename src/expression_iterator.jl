module ExpressionIterator
each_line_iterator(s::AbstractString) = eachline(IOBuffer(s))
end # module ExpressionIterator
