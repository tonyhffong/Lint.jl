@testset "Expression iterator" begin
    let line_array = ["a", "b", "c", "í", "ω", "゛"],
        lines_string = join(line_array, "\n"),
        line_it = Lint.ExpressionIterator.each_line_iterator(lines_string),
        collected_lines = collect(line_it)
        @test eltype(collected_lines) == SubString{String} # need the indices to original string
        @test collected_lines == line_array
    end

    let line_array=collect(map(i->"$i", 1:9)),
        lines_string=join(line_array, "\n"),
        lines_offsets = collect(Lint.ExpressionIterator.lines_offsets(lines_string)),
        expected_offsets = [(i*2-1,i*2-1) for i in 1:9] # "1", "\n", … "7", "\n" …
        @test lines_offsets == expected_offsets
        @test [lines_string[r[1]:r[2]] for r in lines_offsets] == line_array
    end

    let s = """
            function f()
            x = 0
            x
            end
            """,
        lines = collect(Lint.ExpressionIterator.each_line_iterator(s)),
        lines_offsets = collect(Lint.ExpressionIterator.lines_offsets(s)),
        lines_per_offsets = [SubString(s, t[1], t[2]) for t in lines_offsets]
        @test lines == [SubString(s, t[1], t[2]) for t in lines_offsets]
        @test collect(Lint.ExpressionIterator.each_expression(s)) == [Meta.parse(s)]
    end

    let s = """
            function f()
            x = zeros(10, 10)
            x
            end
            """,
        lines = collect(Lint.ExpressionIterator.each_line_iterator(s)),
        lines_offsets = collect(Lint.ExpressionIterator.lines_offsets(s)),
        lines_per_offsets = [SubString(s, t[1], t[2]) for t in lines_offsets]
        @test lines == [SubString(s, t[1], t[2]) for t in lines_offsets]
        @test collect(Lint.ExpressionIterator.each_expression(s)) == [Meta.parse(s)]
    end
end
