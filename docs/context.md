# LintContext

`LintContext` is used internally by Lint.jl to keep track everything while it
is linting. A `LintContext` is created when you call `lintpkg`, `lintfile` or
`lintstr`. You can also create, manipulate and pass your own `LintContext` for
the lint functions to use instead.

Note that `LintContext` is an implementation detail and is subject to change in
future versions of Lint.

## Advanced lint helper interface information
* the context argument `ctx` has a field called `data` typed `Dict{Symbol,Any}`.
 Access it using `ctx.callstack[end].data`.
 Use it to store anything, although you should be careful of colliding
 name space with other modules' `lint_helper`. It is particularly useful
 for storing current lint context, such as when a certain macro is only allowed
 inside another macro.
* If your macro generates new local variables, call this:
```julia
ctx.callstack[end].localvars[end][varsymbol] = ctx.line
```
* If your macro generates new free variables (not bound to a block scope), call this:
```julia
ctx.callstack[end].localvars[1][varsymbol] = ctx.line
```
* If your macro generates new functions,
```julia
push!(ctx.callstack[end].functions, funcsymbol)
```
* If your macro generates new types,
```julia
push!(ctx.callstack[end].types, roottypesymbol)
```
You just need to put in the root symbol for a parametric type, for example
`:A` for `A{T<:Any}`.
