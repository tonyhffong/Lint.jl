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

    @test chomp(readline(conn)) == ""

    conn = connect(port)
    write(conn, "undeclared_symbol\n")
    write(conn, "4\n")
    write(conn, "bad\n")

    @test contains(readline(conn), "use of undeclared symbol")
    @test chomp(readline(conn)) == ""
end

@testset "Testing the lintserver addition" begin
    str = """
          test = "Hello" + "World"
          """
    socket = connect(port)
    lintbyserver(socket,str)
    response = readfromserver_old(socket)
    @test response == "none:1 E422 : string uses * to concatenate\n"

    socket = connect(port)
    lintbyserver(socket,str)
    res = readfromserver_new(socket)
    @test res == "none:1 E422 : string uses * to concatenate\n\n"
end

@testset "Testing lintserver() with named pipe and JSON format" begin
    if is_windows()
        pipe = "\\\\.\\pipe\\testsocket"
        pipe2 = "\\\\.\\pipe\\testsocket2"
        pipe3 = "\\\\.\\pipe\\testsocket3"
        pipe4 = "\\\\.\\pipe\\testsocket4"
    else
        pipe = tempname()
        pipe2 = tempname()
        pipe3 = tempname()
        pipe4 = tempname()
    end
    server_LintMessage = @async lintserver(pipe,"lint-message")
    sleep(1)
    socket = connect(pipe)
    json_input = JSON.json(Dict("file" => "none", "code_str" => "something"))
    write(socket, json_input * "\n")
    json_output = readline(socket)
    results_array = JSON.parse(strip(json_output))
    @test results_array[1]["line"] == 1
    @test results_array[1]["message"] == "use of undeclared symbol"
    @test results_array[1]["file"] == "none"
    @test results_array[1]["code"] == "E321"

    server_slv1 = @async lintserver(pipe2,"standard-linter-v1")
    sleep(1)
    socket = connect(pipe2)
    write(socket, json_input * "\n")
    json_output = readline(socket)
    results_array = JSON.parse(strip(json_output))
    @test results_array[1]["text"] == "E321 something use of undeclared symbol"
    @test results_array[1]["filePath"] == "none"
    @test results_array[1]["range"] == Array[[0, 0], [0, 80]]
    @test results_array[1]["type"] == "error"


    socket = connect(pipe2)
    json_input2 = JSON.json(Dict("file" => "none",
                                 "code_str" => "pi=3"))
    write(socket, json_input2 * "\n")
    json_output = readline(socket)
    results_array = JSON.parse(strip(json_output))
    @test results_array[1]["text"] == "W351 pi redefining mathematical constant"
    @test results_array[1]["filePath"] == "none"
    @test results_array[1]["range"] == Array[[0, 0], [0, 80]]
    @test results_array[1]["type"] == "warning"

    socket = connect(pipe2)
    json_input3 = JSON.json(Dict("file" => "none",
                                 "code_str" => "function a(b)\nend"))
    write(socket, json_input3 * "\n")
    json_output = readline(socket)
    results_array = JSON.parse(strip(json_output))
    @test results_array[1]["text"] == "I382 b argument declared but not used"
    @test results_array[1]["filePath"] == "none"
    @test results_array[1]["range"] == Array[[0, 0], [0, 80]]
    @test results_array[1]["type"] == "info"


    server_vscode = @async lintserver(pipe3,"vscode")
    sleep(1)
    socket = connect(pipe3)
    write(socket, json_input * "\n")
    json_output = readline(socket)
    results_array = JSON.parse(strip(json_output))
    @test results_array[1]["message"] == "something use of undeclared symbol"
    @test results_array[1]["filePath"] == "none"
    @test results_array[1]["range"] == Array[[0, 0], [0, 80]]
    @test results_array[1]["code"] == "E321"
    @test results_array[1]["severity"] == 1
    @test results_array[1]["source"] == "Lint.jl"


    server_slv2 = @async lintserver(pipe4,"standard-linter-v2")
    sleep(1)
    socket = connect(pipe4)
    write(socket, json_input * "\n")
    json_output = readline(socket)
    results_array = JSON.parse(strip(json_output))
    @test results_array[1]["description"] == "something use of undeclared symbol"
    @test results_array[1]["location"]["file"] == "none"
    @test results_array[1]["location"]["position"] == Array[[0, 0], [0, 80]]
    @test results_array[1]["severity"] == "error"
    @test results_array[1]["excerpt"] == "E321"


    json_input = JSON.json(Dict("file" => "none",
                                "code_str" => "function a(b)\nend",
                                "ignore_info" => true))
    socket = connect(pipe)
    write(socket, json_input * "\n")
    json_output = readline(socket)
    results_array = JSON.parse(strip(json_output))
    @test isempty(results_array)

    json_input = JSON.json(Dict("file" => "none",
                                "code_str" => "pi = 1",
                                "ignore_warnings" => true))
    socket = connect(pipe)
    write(socket, json_input * "\n")
    json_output = readline(socket)
    results_array = JSON.parse(strip(json_output))
    @test isempty(results_array)

    json_input = JSON.json(Dict("file" => "none",
                                "code_str" => "pi = 1\nfunction a(b)\nend",
                                "ignore_codes" => ["I382","W351"]))
    socket = connect(pipe)
    write(socket, json_input * "\n")
    json_output = readline(socket)
    results_array = JSON.parse(strip(json_output))
    @test isempty(results_array)
end
