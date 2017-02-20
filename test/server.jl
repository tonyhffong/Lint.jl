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
    server_LintMessage = @async lintserver(pipe,"LintMessage")
    sleep(1)
    socket = connect(pipe)
    lintbyserver(socket,"something")
    json_output = readline(socket)
    result_dict = JSON.parse(strip(json_output))
    @test result_dict[1]["line"] == 1
    @test result_dict[1]["message"] == "use of undeclared symbol"
    @test result_dict[1]["file"] == "none"
    @test result_dict[1]["code"] == "E321"


    server_slv1 = @async lintserver(pipe2,"standard-linter-v1")
    sleep(1)
    socket = connect(pipe2)
    lintbyserver(socket,"something")
    json_output = readline(socket)
    result_dict = JSON.parse(strip(json_output))
    @test result_dict[1]["text"] == "E321 something use of undeclared symbol"
    @test result_dict[1]["filePath"] == "none"
    @test result_dict[1]["range"] == Array[[1, 0], [1, 80]]
    @test result_dict[1]["type"] == "error"


    server_vscode = @async lintserver(pipe3,"vscode")
    sleep(1)
    socket = connect(pipe3)
    lintbyserver(socket,"something")
    json_output = readline(socket)
    result_dict = JSON.parse(strip(json_output))
    @test result_dict[1]["message"] == "something use of undeclared symbol"
    @test result_dict[1]["filePath"] == "none"
    @test result_dict[1]["range"] == Array[[1, 0], [1, 80]]
    @test result_dict[1]["code"] == "E321"
    @test result_dict[1]["severity"] == 1
    @test result_dict[1]["source"] == "Lint.jl"


    server_slv2 = @async lintserver(pipe4,"standard-linter-v2")
    sleep(1)
    socket = connect(pipe4)
    lintbyserver(socket,"something")
    json_output = readline(socket)
    result_dict = JSON.parse(strip(json_output))
    @test result_dict[1]["description"] == "something use of undeclared symbol"
    @test result_dict[1]["location"]["file"] == "none"
    @test result_dict[1]["location"]["position"] == Array[[1, 0], [1, 80]]
    @test result_dict[1]["severity"] == "error"
    @test result_dict[1]["excerpt"] == "E321"
end

# This isn't working on the nightly build. Ideally we explicitly stop the server process (as
# it loops forever). It seems to get stopped when the tests end, so it's not necessary.
#
#try # close the server
#    Base.throwto(server, InterruptException())
#end
