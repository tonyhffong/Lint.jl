@testset "E332" begin
    s = """
    function f()
        call = "hi" # this is just asking for trouble
        call
    end
    """
    msgs = lintstr(s)
    @test msgs[1].code == :E332
    @test msgs[1].variable == "call"
end

@testset "I342" begin
    let variable_with_conflicting_name = "+",
        s = """
        function f()
            $(variable_with_conflicting_name) = "hi"
            $(variable_with_conflicting_name)
        end
        """
        msgs = lintstr(s)
        @test msgs[1].code == :I342
        @test msgs[1].variable == variable_with_conflicting_name
    end
end
