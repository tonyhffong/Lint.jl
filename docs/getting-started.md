# Getting Started

You have installed Lint.jl and now you want to use it to find potential problems in your code. There are 3 functions you can use to lint your code.

* [lintpkg](#lintpkg) for linting an entire package
* [lintfile](#lintfile) for linting a file
* [lintstr](#lintstr) for linting a string

You have to include Lint before you can use it:
```julia
using Lint
```


## lintpkg

`lintpkg` is used for linting an entire package.
```julia
lintpkg("MyPackage")
```

If your package always lints clean, you may want to keep it that way in a test:
```julia
@test isempty(lintpkg("MyPackage"))
```


## lintfile

`lintfile` is used for linting a file.
```julia
lintfile("your_file.jl")
```

`lintfile` will follow any `include` statements to resolve any variables. But will only return warnings for the file you are linting.


## lintstr

`lintstr` is used for linting a string.
```julia
lintstr("println(\"hello world!\")")
```
