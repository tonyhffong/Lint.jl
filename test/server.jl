# find a good port
conn = listenany(2228)
close(conn[2])
port = conn[1]

server = @async lintserver(port)
sleep(1) #let server start

@testset "lintserver() tests" begin
  conn = connect(port)
  write(conn, "empty\n")
  write(conn, "1\n")
  write(conn, "\n")

  @test readline(conn) == "\n"


  conn = connect(port)
  write(conn, "undeclared_symbol\n")
  write(conn, "4\n")
  write(conn, "bad\n")

  @test contains(readline(conn), "use of undeclared symbol")
  @test readline(conn) == "\n"
end

@testset "Testing the lintserver addition" begin
    function lintbyserver(socket)
        str = """
        test = "Hello" + "World"
        """
        println(socket, "none")
        println(socket, sizeof(str)) # bytes of code
        println(socket, str) # code
    end

    socket = connect(port)
    lintbyserver(socket)
    response = ""
    line = ""
    while line != "\n"
        response *= line
        line = readline(socket)
    end

    @test response == "none:1 E422 : string uses * to concatenate\n"

    socket = connect(port)
    lintbyserver(socket)
    res = ""
    line = ""
    while isopen(socket)
        res *= line
        line = readline(socket)
    end

    @test res == "none:1 E422 : string uses * to concatenate\n\n"
end

# This isn't working on the nightly build. Ideally we explicitly stop the server process (as
# it loops forever). It seems to get stopped when the tests end, so it's not necessary.
#
#try # close the server
#    Base.throwto(server, InterruptException())
#end
