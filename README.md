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

## Current false positives
* Because macros can generate new symbols on the fly. Lint has a hard time dealing
with that.
