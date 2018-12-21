@assert [[1;2];[3;4]] == [1;2;3;4]
let s = """
    r = [[1;2];[3;4]]
    """,
    msgs = lintstr(s)
    @test msgs[1].code == :W444
end

let s = """
    r = [[1,2],[3,4]]
    """,
    msgs = lintstr(s)
    @test isempty(msgs)
end

@assert [[1 2] [3 4]] == [1 2 3 4]
let s = """
    r = [[1 2]  [3 4]]
    """,
    msgs = lintstr(s)
    @test msgs[1].code == :W445
end

let s = """
    x = Any[[1,2],[7,8]]
    y = Array[[1,2],[3,4]]
    """,
    msgs = lintstr(s)
    @test isempty(msgs)
end

let s = """
    function f(x::Array{Float64,2})
    y = x[1, 2, 3]
    y
    end
    """,
    msgs = lintstr(s)
    @test msgs[1].code == :E436
end

let s = """
    function f(x::Array{Float64,2})
    x[1, 2, 3]
    end
    """,
    msgs = lintstr(s)
    @test msgs[1].code == :E436
end

let s = """
    function f(x::Array{Float64,2})
        y = x[Colon(), 1]
        for i in y
            println(i)
        end
    end
    """,
    msgs = lintstr(s)
    @test isempty(msgs)
end

let s = """
    function f(x::Array{Float64,2})
    y = x[1,1]
    @lintpragma("Info type y")
    end
    """,
    msgs = lintstr(s)
    @test msgs[1].code == :I271
end

let s = """
    function f(t)
    x1 = zeros(1, 2)
    x2 = zeros(Int64, 2, 2)
    x3 = zeros(t, 2, 2)
    x4 = zeros(x1)
    @lintpragma("Info type x1")
    @lintpragma("Info type x2")
    @lintpragma("Info type x3")
    @lintpragma("Info type x4")
    end
    """,
    msgs = lintstr(s)
    @test msgs[1].code == :I271
    @test msgs[2].code == :I271

    @test msgs[3].code == :I271

    @test msgs[4].code == :I271
end 

# more array function
let s = """
    function f(t::Array{Int64,2}, m, n)
    x2 = reshape(t, 1)
    x3 = reshape(t, (1,2))
    x4 = reshape(m, (1,2))
    x6 = reshape(t, 1, 2)
    x7 = t'
    x8 = (1, 2)
    @lintpragma("Info type x2")
    @lintpragma("Info type x3")
    @lintpragma("Info type x4")
    @lintpragma("Info type x6")
    @lintpragma("Info type x7")
    @lintpragma("Info type x8")
    end
    """,
    msgs = lintstr(s)
    @test msgs[1].code == :I271
    @test msgs[2].code == :I271
    @test msgs[3].code == :I271
    @test msgs[4].code == :I271
    @test msgs[5].code == :I271
end

let s = """
    function f(a::Array{Float64})
    x = a[1,2]
    @lintpragma("Info type x")
    return x
    end
    """,
    msgs = lintstr(s)
    # it could be Float64, or it could be an array still!
    @test msgs[1].code == :I271
end

let s = """
    s = "abcdef"
    s = s[chr2ind(s,2) :end]
    """,
    msgs = lintstr(s)
    @test msgs[1].code == :I681
end

let s = """
    s = "abcdef"
    sndlast = s[end -1]
    """,
    msgs = lintstr(s)
    @test msgs[1].code == :I682
end

let s = """
    function f()
    x1 = zeros(100, 100)
    x2 = Array(Float64, (100, 100))
    x1[1, 1]
    x2[1, 1]
    end
    """,
    msgs = lintstr(s)
    @test isempty(msgs)
end

let s = """
    function f(y::Array{Float64, 3}, x1::Int64)
    reshape(y[Colon(), x1, Colon()]', size(y, 1), size(y, 3)')
    end
    """,
    msgs = lintstr(s)
    @test isempty(msgs)
end
