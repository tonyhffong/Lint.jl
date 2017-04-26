function convertmsgtojson(msgs, style, dict_data)
    if style == "lint-message"
        return msgs
    end
    output = Any[]
    for msg in msgs
        evar = msg.variable
        txt = msg.message
        f = file(msg)
        linenumber = line(msg)
        # Atom index starts from zero thus minus one
        errorrange = Array[[linenumber-1, 0], [linenumber-1, 80]]
        code = string(msg.code)
        if code[1] == 'I'
            etype = "info"
            etypenumber = 3
        elseif code[1] == 'W'
            etype = "warning"
            etypenumber = 2
        else
            etype = "error"
            etypenumber = 1
        end

        if style == "standard-linter-v1"
            if haskey(dict_data,"show_code")
                if dict_data["show_code"]
                    msgtext = "$code $evar: $txt"
                else
                    msgtext = "$evar: $txt"
                end
            else
                msgtext = "$code $evar: $txt"
            end
            push!(output, Dict("type" => etype,
                               "text" => msgtext,
                               "range" => errorrange,
                               "filePath" => f))
        elseif style == "vscode"
            push!(output, Dict("severity" => etypenumber,
                               "message" => "$evar: $txt",
                               "range" => errorrange,
                               "filePath" => f,
                               "code" => code,
                               "source" => "Lint.jl"))
        elseif style == "standard-linter-v2"
            push!(output, Dict("severity" => etype,
                               "location" => Dict("file" => f,
                                                  "position" => errorrange),
                               "excerpt" => "$evar: $txt",
                               "description" => code))

        end
    end
    return output
end


function filtermsgs(msgs,dict_data)
    if haskey(dict_data,"ignore_warnings")
        if dict_data["ignore_warnings"]
            msgs = filter(i -> !iswarning(i), msgs)
        end
    end
    if haskey(dict_data,"ignore_info")
        if dict_data["ignore_info"]
            msgs = filter(i -> !isinfo(i), msgs)
        end
    end
    if haskey(dict_data,"ignore_codes")
        msgs = filter(i -> !(string(i.code) in dict_data["ignore_codes"]), msgs)
    end
    return msgs
end


function readandwritethestream(conn,style)
    if style == "original_behaviour"
        # println("Connection accepted")
        # Get file, code length and code
        file = readline(conn)
        # println("file: ", file)
        code_len = parse(Int, readline(conn))
        # println("Code bytes: ", code_len)
        code = Compat.UTF8String(read(conn, code_len))
        # println("Code received")
        # Do the linting
        msgs = lintfile(file, code)
        # Write response to socket
        for i in msgs
            write(conn, string(i))
            write(conn, "\n")
        end
        # Blank line to indicate end of messages
        write(conn, "\n")
    else
        dict_data = JSON.parse(conn)
        msgs = lintfile(dict_data["file"], dict_data["code_str"])
        msgs = filtermsgs(msgs, dict_data)
        out = convertmsgtojson(msgs, style, dict_data)
        JSON.print(conn, out)
    end
end

function lintserver(port,style="original_behaviour")
    server = listen(port)
    try
        println("Server running on port/pipe $port ...")
        while true
            conn = accept(server)
            @async try
                readandwritethestream(conn,style)
            catch err
                println(STDERR, "connection ended with error $err")
            finally
                close(conn)
                # println("Connection closed")
            end
        end
    finally
        close(server)
        println("Server closed")
    end
end
