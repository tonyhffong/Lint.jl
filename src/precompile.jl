# Precompile linting some strings for performance

lintstr("""
x, y = 1, 2
for i in 1:10
    println(i)
end
if x == 0
    let z = 1
        println(x + z - y)
    end
elseif x == 1 && y == 2
    println("precompile")
end
""")
