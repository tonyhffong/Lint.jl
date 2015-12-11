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

@test contains(readline(conn), "use of undeclared symbol bad\n")
@test readline(conn) == "\n"

# This isn't working on the nightly build. Ideally we explicitly stop the server process (as
# it loops forever). It seems to get stopped when the tests end, so it's not necessary.
#
#try # close the server
#    Base.throwto(server, InterruptException())
#end
