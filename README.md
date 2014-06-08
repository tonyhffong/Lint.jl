#Lint.jl

## Introduction

Lint.jl is a tool to hunt for imperfections and dodgy structures that could be
improved.

## Installation
```julia
Pkg.add( "Lint" )
```

## Usage
```julia
using Lint
lintfile( "your_.jl_file" )
```
It'd follow any `include` statements.

The output is of the following form:
```
         filename.jl [       function name] Line CODE  Explanation
```
`Line` is the line number relative to the start of the function.
`CODE` gives an indication of severity, and is one of `FYI`, `WARN`, `ERROR`, or `FATAL`.

## What it can find?
* simple deadcode detection (e.g if true/false)
* simple premature-return deadcode detection
* Bitwise `&`, `|` being used in a Bool context. Suggest `&&` and `||`
* declared but unused variable
* Using an undefined variable
* Duplicate key as in `[:a=>1, :b=>2, :a=>3]`
* Exporting non-existing symbols (not fully done yet)
* Exporting the same symbol more than once
* Name overlap between a variable and a lambda argument
* Assignment in an if-predicate, as a potential confusion with `==`
* Suggest explicit declaration of globals in functions
* warn `length()` being used as Bool, suggest `!isempty()`
* Consecutively similar expressions block and that its last part looks different from the rest (work-in-progress)
* Out-of-scope local variable name being reused again inside the same code block. (legal but frowned upon)

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
** if you find an issue in your expression, call `Lint.msg( ctx, level, "explanation" )`
** level is 0: FYI, 1:WARN, 2:ERROR, 4:FATAL
* typical structure looks like this
```
function lint_helper( ex::Expr, ctx )
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
* To run, you must make sure your Julia session already knows about your package by
having done `using <your package>` first.

## Advanced lint helper interface information
* the context argument `ctx` has a field called `data` typed `Dict{Symbol,Any}`.
 Access it using `ctx.callstack[end].data`.
 Use it to store anything, although you should be careful of colliding
 name space with other modules' `lint_helper`. It is particularly useful
 for storing current lint context, such as when a certain macro is only allowed
 inside another macro.
* If your macro generates new local variables, call this:
```
ctx.callstack[end].localvars[end][ varsymbol ] = ctx.line
```
* If your macro generates new free variables (not bound to a block scope), call this:
```
ctx.callstack[end].localvars[1][ varsymbol ] = ctx.line
```
* If your macro generates new functions,
```
push!( ctx.callstack[end].functions, funcsymbol )
```
* If your macro generates new types,
```
push!( ctx.callstack[end].types, roottypesymbol )
```
You just need to put in the root symbol for a parametric type, for example
`:A` for `A{T<:Any>}`.
