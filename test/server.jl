import Compat: readline

# find a good port
conn = listenany(2228)
close(conn[2])
port = conn[1]

server = @async lintserver(port)
sleep(1) #let server start

function lintbyserver(socket,str)
    println(socket, "none")
    println(socket, sizeof(str)) # bytes of code
    println(socket, str) # code
end

function readfromserver_old(socket)
    response = ""
    line = ""
    while line != "\n"
        response *= line
        line = readline(socket)
    end
    return response
end

function readfromserver_new(socket)
    response = ""
    line = ""
    while isopen(socket)
        response *= line
        line = readline(socket)
    end
    return response
end


@testset "lintserver() tests" begin
    conn = connect(port)
    write(conn, "empty\n")
    write(conn, "1\n")
    write(conn, "\n")

    @test readline(conn) == ""

    conn = connect(port)
    write(conn, "undeclared_symbol\n")
    write(conn, "4\n")
    write(conn, "bad\n")

    @test contains(readline(conn), "use of undeclared symbol")
    @test readline(conn) == ""
end

@testset "Testing the lintserver addition" begin
    str = """
          test = "Hello" + "World"
          """
    socket = connect(port)
    lintbyserver(socket, str)
    response = String[]
    line = "."
    while !isempty(line)
        line = readline(socket)
        push!(response, line)
    end

    @test "none:1 E422 : string uses * to concatenate" in response

    socket = connect(port)
    lintbyserver(socket, str)
    response = String[]
    while isopen(socket)
        line = readline(socket)
        push!(response, line)
    end

    @test "none:1 E422 : string uses * to concatenate" in response
end

@testset "Testing lintserver() with named pipe and JSON format" begin
    if is_windows()
        pipe_lm = "\\\\.\\pipe\\testsocket"
        pipe_slv1 = "\\\\.\\pipe\\testsocket2"
        pipe_vscode = "\\\\.\\pipe\\testsocket3"
        pipe_slv2 = "\\\\.\\pipe\\testsocket4"
    else
        pipe_lm = tempname()
        pipe_slv1 = tempname()
        pipe_vscode = tempname()
        pipe_slv2 = tempname()
    end

    function writeandreadserver(pipe,json_input)
        conn = connect(pipe)
        JSON.print(conn, json_input)
        JSON.parse(conn)
    end

    server_lm = @async lintserver(pipe_lm,"lint-message")
    server_slv1 = @async lintserver(pipe_slv1,"standard-linter-v1")
    server_vscode = @async lintserver(pipe_vscode,"vscode")
    server_slv2 = @async lintserver(pipe_slv2,"standard-linter-v2")
    sleep(1)

    json_input1 = Dict("file" => "none", "code_str" => "something")
    json_input2 = Dict("file" => "none", "code_str" => "pi=3")
    json_input3 = Dict("file" => "none", "code_str" => "function a(b)\nend")

    results_array = writeandreadserver(pipe_lm, json_input1)
    @test_broken results_array[1]["line"] == 1
    @test results_array[1]["message"] == "use of undeclared symbol"
    @test_broken results_array[1]["file"] == "none"
    @test results_array[1]["code"] == "E321"

    results_array = writeandreadserver(pipe_slv1, json_input1)
    @test results_array[1]["text"] == "E321 something: use of undeclared symbol"
    @test results_array[1]["filePath"] == "none"
    @test results_array[1]["range"] == Array[[0, 0], [0, 80]]
    @test results_array[1]["type"] == "error"

    results_array = writeandreadserver(pipe_slv1, json_input2)
    @test startswith(results_array[1]["text"], "I343 pi: global variable")
    @test results_array[1]["filePath"] == "none"
    @test results_array[1]["range"] == Array[[0, 0], [0, 80]]
    @test results_array[1]["type"] == "info"

    results_array = writeandreadserver(pipe_slv1, json_input3)
    @test startswith(results_array[1]["text"], "I340 b: unused local variable")
    @test results_array[1]["filePath"] == "none"
    @test_broken results_array[1]["range"] == Array[[0, 0], [0, 80]]
    @test results_array[1]["type"] == "info"

    results_array = writeandreadserver(pipe_vscode, json_input1)
    @test results_array[1]["message"] == "something: use of undeclared symbol"
    @test results_array[1]["filePath"] == "none"
    @test results_array[1]["range"] == Array[[0, 0], [0, 80]]
    @test results_array[1]["code"] == "E321"
    @test results_array[1]["severity"] == 1
    @test results_array[1]["source"] == "Lint.jl"

    results_array = writeandreadserver(pipe_slv2, json_input1)
    @test results_array[1]["description"] == "E321"
    @test results_array[1]["location"]["file"] == "none"
    @test results_array[1]["location"]["position"] == Array[[0, 0], [0, 80]]
    @test results_array[1]["severity"] == "error"
    @test results_array[1]["excerpt"] == "something: use of undeclared symbol"


    json_input4 = Dict("file" => "none", "code_str" => "function a(b)\nend",
                       "ignore_info" => true)
    results_array = writeandreadserver(pipe_lm, json_input4)
    @test isempty(results_array)

    json_input5 = Dict("file" => "none", "code_str" => "pi = 1",
                       "ignore_warnings" => true)
    results_array = writeandreadserver(pipe_lm, json_input5)
    @test_broken isempty(results_array)

    json_input6 = Dict("file" => "none",
                       "code_str" => "pi = 1\nfunction a(b)\nend",
                       "ignore_codes" => ["I340","I343"])
    results_array = writeandreadserver(pipe_lm, json_input6)
    @test isempty(results_array)

    json_input7 = Dict("file" => "none",
                       "code_str" => "pi = 1\nfunction a(b)\nend",
                       "show_code" => false)
    results_array = writeandreadserver(pipe_slv1, json_input7)
    @test startswith(results_array[1]["text"], "pi: global variable")
    @test results_array[1]["filePath"] == "none"
    @test_broken results_array[1]["range"] == Array[[0, 0], [0, 80]]
    @test_broken results_array[1]["type"] == "warning"

    json_input8 = Dict("file" => "none",
                       "code_str" => "pi = 1\nfunction a(b)\nend",
                       "show_code" => true)
    results_array = writeandreadserver(pipe_slv1, json_input8)
    @test startswith(results_array[1]["text"], "I343 pi: global variable")
    @test results_array[1]["filePath"] == "none"
    @test_broken results_array[1]["range"] == Array[[0, 0], [0, 80]]
    @test results_array[1]["type"] == "info"
end
