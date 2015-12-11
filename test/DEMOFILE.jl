# not executable code, but something Lint would pick up
function f(x)
    @lintpragma("Info me this is a deliberate test message.")
    z = x + y + y * y
    @lintpragma("Info me additional test reminder:\nIGNORE ME")
end
