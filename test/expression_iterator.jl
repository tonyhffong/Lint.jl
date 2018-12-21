@testset "Expression iterator" begin
    let line_array=["a", "b", "c", "í", "ω", "゛"],
        lines_string=join(line_array, "\n"),
        line_it=Lint.ExpressionIterator.each_line_iterator(lines_string),
        collected_lines=collect(line_it)
        @test eltype(collected_lines) == SubString{String} # need the indices to original string
        @test collected_lines == line_array
    end
    let line_array=collect(map(i->"$i", 1:9)),
        lines_string=join(line_array, "\n"),
        lines_with_offsets = collect(Lint.ExpressionIterator.offset_lines(lines_string)),
        expected_offsets = [i*2-1 for i in 1:9],
        expected_lines_with_offsets=collect(zip(line_array, expected_offsets))
        @test lines_with_offsets == expected_lines_with_offsets
    end
end
