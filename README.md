#Lint.jl

## Introduction

Lint.jl is a tool to hunt for imperfections and dodgy structures that could be
improved.

## Installation
```julia
Pkg.add( “Lint” )
```

## Usage
```julia
using Lint
lintfile( "your_.jl_file” )
```

## What it can find?
* simple deadcode detection (e.g if true/false)
* simple premature-return deadcode detection
* &, | being used in a Bool context. Suggest && and ||
* declared but unused variable
* Using a undefined variable
* Export non-existing symbols (not fully done yet)
* Export the same symbol twice or more.
* Name overlap between a variable and a lambda argument
* Assignment in an if-predicate, as a potential confusion with “==”
* Suggest explicit declaration of globals in functions
* warn length() being used as Bool, suggest !isempty()

## Current false positives
* Because macros can generate new symbols on the fly. Lint has a hard time dealing
with that.
