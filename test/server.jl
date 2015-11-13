# find a good port
conn = listenany(2228)
close(conn[2])
port = conn[1]

server = @async lintserver(port)
sleep(1) #let sever start


conn = connect(port)
write(conn, "empty\n")
write(conn, "1\n")
write(conn, "\n")

@test readline(conn) == "\n"


conn = connect(port)
write(conn, "undeclared_symbol\n")
write(conn, "4\n")
write(conn, "bad\n")

@test contains(readline(conn), "Use of undeclared symbol bad\n")
@test readline(conn) == "\n"


try # close the server
    Base.throwto(server, InterruptException())
end
