@testset "Expression iterator" begin
    let s="""
a
b
c""",
        line_it=Lint.ExpressionIterator.each_line_iterator(s)
        @test collect(line_it) == ["a", "b", "c"]
    end

end
