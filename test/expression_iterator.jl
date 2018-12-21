@testset "Expression iterator" begin
    let s="""
a
b
c
í
ω
゛
""",
        line_it=Lint.ExpressionIterator.each_line_iterator(s),
        lines=collect(line_it)
        @test eltype(lines) == SubString{String} # need the indices to original string
        @test lines == ["a", "b", "c", "í", "ω", "゛"]
    end

end
