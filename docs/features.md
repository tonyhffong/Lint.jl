# Features

## @lintpragma: steering Lint-time behavior
You can insert @lintpragma to suppress or generate messages. At runtime, @lintpragma is a no-op, so it gives
no performance penalty.
However, at lint-time, these pragmas steer the lint behavior. Module designers do not even have to import
the macro from Lint.jl in their module, as long as they just create an empty macro like this, early in their
module scripts:
```julia
macro lintpragma(s)
end
```

Lint message suppression (do not include the square brackets)

* `@lintpragma("Ignore unused [variable name]")`. Works for unused arguments also.
* `@lintpragma("Ignore unstable type variable [variable name]")`. Ignore type instability warnings.
* `@lintpragma("Ignore deprecated [function name]")`
* `@lintpragma("Ignore undefined module [module name]")`. Useful to support Julia packages across 
    different Julia releases.
* `@lintpragma("Ignore untyped field [field name]")`.
* `@lintpragma("Ignore dimensionless array field [field name]")`. Useful if we really want to store 
    arrays with uncertain/runtime-calculated dimension
* `@lintpragma("Ignore use of undeclared variable [variable name]")`. Useful when using macros to
  generate symbols on the fly.
* `@lintpragma("Ignore incompatible type comparison")`. Useful to silence deliberately different-type comparison

Lint message generation (do not include the square brackets)

* `@lintpragma("Info type [expression]")`. Generate the best guess type of the expression during lint-time.
* `@lintpragma("Info me [any text]")`. An alternative to-do.
* `@lintpragma("Warn me [any text]")`. Remind yourself this code isn't done yet.
* `@lintpragma("Error me [any text]")`. Remind yourself this code is wrong.

The macro also supports lint-time terminal output that generates no Lint message:

* `@lintpragma("Print type [expression]")`. Just print out the type
* `@lintpragma("Print me [any text]")`. Lint-time printing

Useful version tracing tool

* `@lintpragma("Info version [version]")`. lint-time version reachability test


## VERSION branch

As julia evolves, some coding style that is an error becomes valid (and vice versa). It is common to use
VERSION if-statements to implement cross-version packages. As long as the if statement is simple,
Lint can pick them up and suppress version-dependent errors that are not reachable in the current version.

Examples:
```julia
# lint won't complaint about missing `Base.Dates` in 0.3 or missing `Dates` in 0.4
if VERSION < v"0.4-"
    using Dates
else
    using Base.Dates
end
```

```julia
# this passes lint in 0.3 but it generates an INFO in 0.4
s = symbol("end")
```

```julia
# this is an error 0.3 but it passes in 0.4
s = Symbol("end")
```

```julia
# this will lint clean cross versions
if VERSION < v"0.4-"
    s = symbol("end")
else
    s = Symbol("end")
end
```

You can directly test for version reachability by inserting lint-pragmas
like so
```julia
if VERSION >= v"0.4-"
    @lintpragma("Info version 0.3")
    @lintpragma("Info version 0.4.0-dev+1833")
else
    @lintpragma("Info version 0.3")
    @lintpragma("Info version 0.4.0-dev+1833")
end
```
You will see line-by-line reachability in your output. See test/versions.jl
for further examples.

## Current false positives
* Because macros can generate new symbols on the fly. Lint will have a hard time dealing
with that. To help Lint and to reduce noise, module designers can add a
`lint_helper` function to their module.


## Module specific lint helper(WIP)
Key info about adding a `lint_helper` function in your module

* You don't need to export this function. Lint will find it.
* It must return true if an expression is part of your module's
  enabling expression (most likely a macrocall). Return false otherwise
  so that Lint can give other modules a go at it. Note that
  if you always returning true in your code you will break Lint.
* `lint_helper` takes two argument, an `Expr` instance and a context.
  - if you find an issue in your expression, call `Lint.msg(ctx, code, variable, "explanation")`
* typical structure looks like this
```julia
function lint_helper(ex::Expr, ctx)
    if ex.head == :macrocall
        if ex.args[1] == symbol("@fancy_macro1")
            # your own checking code
            return true
        elseif ex.args[1]== symbol("@fancy_macro2")
            # more checking code
            return true
        end
    end
    return false
end
```

See [advanced lint helper interface](context/#advanced-lint-helper-interface-information) for details on how to use `ctx`.


## Ignoring messages

```julia
julia> s = """
       a = :bar
       @eval \$a = 5
       bar
       """
julia> lintstr(s)
1-element Array{Lint.LintMessage,1}:
 none:3 E321 bar: use of undeclared symbol
```
Using the keyword argument `ignore` you can create a [LintContext](context/#lintcontext) that will ignore any messages you specified.
`ignore` takes and array of `LintIgnore`. `LintIgnore` is a combinition of a messages error code and the messages variable.
```julia
julia> ctx = LintContext("none", ignore=[Lint.LintIgnore(:E321, "bar")])
julia> @test isempty(lintstr(s, ctx))
```

## Lintserver

Make Julia start listening on a given port and return lint messages to requests on that connection.
This feature is useful when you want to lint julia code in a non julia environment (e.g. an IDE like Sublime Text).

The protocol for the server is:

1. The file path followed by a new line
2. The number of bytes of code being sent followed by a new line
3. The actual code

The server will respond with the messages produced when linting the code followed by a empty line (i.e. if it linted cleanly it will respond with a single newline).

Launch the server:
```julia
using Lint
lintserver(2222)
```

Connect and send requests:
```julia
socket = connect(2222)

println(socket, "none") # filename

str = """
test = "Hello" + "World"
"""

println(socket, sizeof(str)) # bytes of code
println(socket, str) # code

response = ""
line = ""
while line != "\n"
    response *= line
    line = readline(socket)
end

@assert response == "none:1 E422 : string uses * to concatenate\n"
```

Note that the first request might take some time because the linting functions are being imported and compiled.
