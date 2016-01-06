# Lint.jl

[![Build Status](https://travis-ci.org/tonyhffong/Lint.jl.svg?branch=master)](https://travis-ci.org/tonyhffong/Lint.jl)
[![Coverage Status](https://img.shields.io/coveralls/tonyhffong/Lint.jl.svg)](https://coveralls.io/r/tonyhffong/Lint.jl)  
[![Lint](http://pkg.julialang.org/badges/Lint_0.3.svg)](http://pkg.julialang.org/?pkg=Lint&ver=0.3)
[![Lint](http://pkg.julialang.org/badges/Lint_0.4.svg)](http://pkg.julialang.org/?pkg=Lint&ver=0.4)
[![Lint](http://pkg.julialang.org/badges/Lint_0.5.svg)](http://pkg.julialang.org/?pkg=Lint&ver=0.5)


Lint.jl is a tool that uses static analysis to assist in the development process by detecting common bugs and potential issues.


## Installation

Lint.jl can be installed through the Julia package manager:
```julia
Pkg.add("Lint")
```


## Usage

There are 3 functions you can use to lint your code.

* `lintpkg("MyPackage")` for linting an entire package
* `lintfile("my_file.jl")` for linting a file
* `lintstr("my string")` for linting a string


## Documentation

Detailed documentation is available for:
* [Latest Release](https://lintjl.readthedocs.org/en/stable/)
* [Development](https://lintjl.readthedocs.org/en/latest/)
