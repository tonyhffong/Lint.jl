# LintContext

`LintContext` is used internally by Lint.jl to keep track everything while it
is linting. A `LintContext` is created when you call `lintpkg`, `lintfile` or
`lintstr`. You can also create, manipulate and pass your own `LintContext` for
the lint functions to use instead.

Note that `LintContext` is an implementation detail and is subject to change in
future versions of Lint.
