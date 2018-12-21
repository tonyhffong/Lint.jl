@testset "Expression iterator" begin
    let line_array=["a", "b", "c", "í", "ω", "゛"],
        lines_string=join(line_array, "\n"),
        line_it=Lint.ExpressionIterator.each_line_iterator(lines_string),
        collected_lines=collect(line_it)
        @test eltype(collected_lines) == SubString{String} # need the indices to original string
        @test collected_lines == line_array
    end
end
