# LintMessage

When you lint some code, Lint.jl will print the error messages in the [format
described below](#format). Lint will return a `LintResult` which behaves like an
iterable of `LintMessage`s.

```julia
lintpkg("MyPackage")
```

## Format
A message is of the following form:
```
filename.jl:Line CODE variable: message
```
`filename.jl` is the file that contains the problem.  
`Line` is the line number relative to the start of the file.  
`CODE` identifies the error and gives an indication of severity.  
`variable` is the variable causing the error.  
`message` is an explanation of the error.  

## Levels

There are 3 levels of severity a LintMessage can be:

* **Error:** The most severe level. Will probably lead to program failure.
* **Warning:** Code that will run but is probably wrong.
* **Info:** Suggestions and best practices.

You can use `iserror`, `iswarning` and `isinfo` to check a particular messages error level.

If you only want to test for error and warning level messages you could use:
```julia
errors = filter(i -> !isinfo(i), lintpkg("MyPackage"))
@test isempty(errors)
```

## Errors codes
Every error code starts with letter for the severity `E`:`ERROR`, `W`:`WARN` or `I`:`INFO` then has 3 numbers identifying the error. Below is a complete list of error codes:

| code   | sample message                                                                                   |
| :----: | :---------------                                                                                 |
| **E1** | *Parsing Error*
| E111   | failed to parse
| E112   | incomplete expression
| E121   | Lint does not understand the expression
| E131   | Lint does not understand the argument #i
| E132   | lint does not understand the argument
| E133   | unknown keyword pattern
| E134   | unknown global pattern
| E135   | local declaration not understood by Lint
| E136   | Lint does not understand macro
| E137   | lintpragma must be called using only string literals
| E138   | incomplete pragma expression
| E139   | Lint fails to parse type: error
|        |
| **E2** | *Miscellaneous Error*
| E211   | deprecated message
| E221   | custum error
|        |
| **E3** | *Existence Error*
| E311   | cannot find include file
| E321   | use of undeclared symbol
| E322   | exporting undefined symbol
| E331   | duplicate argument
| E332   | should not be used as a variable name
| E333   | duplicate exports of symbol
| E334   | duplicate key in Dict
|        |
| **E4** | *Usage Error*
| E411   | non-default argument following default arguments
| E412   | named ellipsis ... can only be the last argument
| E413   | positional ellipsis ... can only be the last argument
| E414   | using is not allowed inside function definitions
| E415   | export is not allowed inside function definitions
| E416   | import is not allowed inside function definitions
| E417   | anonymous function inside type definition
| E418   | RHS is a tuple, n of m variables used
| E421   | use Union{...}, with curly, instead of parentheses
| E422   | string uses * to concatenate
| E423   | named keyword argument must have a default
| E424   | nested vect is treated as a 1-dimensional array. Use [a;b] instead
| E425   | use lintpragma macro inside type declaration
| E431   | use of length() in a Boolean context, use isempty()
| E432   | though valid in 0.4, use x() instead of y()
| E433   | for a decreasing range, use a negative step e.g. 10:-1:1
| E434   | value at position #i is the referenced x. Possible typo?
| E435   | new is provided with more arguments than fields
| E436   | more indices than dimensions
|        |
| **E5** | *Type Error*
| E511   | apparent non-Bool type
| E512   | lint doesn't understand expresion in a boolean context
| E513   | leaf type as a type constraint it makes no sense
| E516   | type assertion and default seem inconsistent
| E517   | constructor-like function name doesn't match type T
| E518   | key type expects X, provided Y
| E519   | string[] expects Integer, provided X
| E521   | apparent type T is not a container type
| E522   | macro arguments can only be Symbol/Expr
| E523   | constructor parameter collides with a type parameter
| E524   | bitstype needs its 2nd argument to be a new type symbol
| E525   | is of an immutable type
| E531   | multiple key types detected. Use Dict{Any,V}() for mixed type dict
| E532   | multiple value types detected. Use Dict{K,Any}() for mixed type dict
| E533   | type parameters are invariant, try f{T<:Number}(x::T)...
| E534   | introducing a new name for an implicit argument to the function, use {T<:X}
| E535   | introducing a new name for an algebric data type, use {T<:X}
| E536   | use {T<:...} instead of a known type
| E537   | String constructor does not exist in v0.4; use string() instead
| E538   | known type in parametric data type, use {T<:...}
|        |
| **E6** | *Structure Error*
| E611   | constructor doesn't seem to return the constructed object
|        |
| **W2** | *Miscellaneous Warning*
| W241   | custum warning
| W251   | error; Symbol= X; rhstype= ...
|        |
| **W3** | *Existence Warning*
| W341   | local variable declared but not used
| W351   | redefining mathematical constant
| W352   | lambda argument conflicts with a local variable
| W353   | lambda argument conflicts with an argument
| W354   | lambda argument conflicts with an declared global
| W355   | conflicts with function name
|        |
| **W4** | *Usage Warning*
| W441   | probably illegal use of inside curly
| W443   | did you forget an -> after @doc or make it inline?
| W444   | nested vcat is treated as a 1-dimensional array
| W445   | nested hcat is treated as a 1-row horizontal array of dim=2
| W446   | too many type parameters
| W447   | can't be #i type parameter for h; it should be of type t2
| W448   | an exception is instantiated but it is not being thrown
|        |
| **W5** | *Type Warning*
| W541   | doesn't eval into a Module
| W542   | comparing apparently incompatible types
| W543   | cannot determine if DataType or not
| W544   | cannot determine if DataType or not
| W545   | previously used variable has apparent type X, but now assigned Y
|        |
| **W6** | *Structure Warning*
| W641   | unreachable code after return
| W642   | true branch is unreachable
| W643   | false branch is unreachable
| W644   | redundant if-true statement
| W645   | while false block is unreachable
| W651   | the last of a expresion block looks different. Avg similarity score: X; Last part: Y
|        |
| **I1** | *Parsing Info*
| I171   | LHS in assignment not understood by Lint
|        |
| **I2** | *Miscellaneous Info*
| I271   | custum info
| I281   | error; Signature: ...
|        |
| **I3** | *Existence Info*
| I371   | use of undeclared symbol
| I372   | unable to follow non-literal include file
| I381   | unused lintpragma
| I382   | argument declared but not used
| I391   | also a global from src
| I392   | local variable might cause confusion with a synonymous export from Base
|        |
| **I4** | *Usage Info*
| I472   | assignment in the if-predicate clause
| I473   | value at position #i is the referenced y. OK if it represents permutations
| I474   | iteration generates tuples, n of m variables used
| I475   | bit-wise in a boolean context. (&, |) do not have short-circuit behavior
| I481   | in 0.4+, replace x() with y()
| I482   | used in a local scope. Improve readability by using 'local' or another name
| I483   | {} may be deprecated. Use Any[]
| I484   | untyped dictionary {a=>b for (a,b) in c}, may be deprecated. Use (Any=>Any)[a=>b for (a,b) in c]
| I485   | untyped dictionary {a for a in c}, may be deprecated. Use (Any)[a for a in c]
| I486   | dictionary [a=>b,...], may be deprecated. Use @compat Dict(a=>b,...)
| I487   | (K=>V)[a=>b,...] may be deprecated. Use @compat Dict{K,V}(a=>b,...)
|        |
| **I5** | *Type Info*
| I571   | the 1st statement under the true-branch is a boolean expression
| I572   | assert x type= X but assign a value of Y
| I581   | (removed in Lint 0.3.0)
|        |
| **I6** | *Structure Info*
| I671   | new is provided with fewer arguments than fields
| I672   | iteration works for a number but it may be a typo
| I681   | ambiguity of :end as a symbol vs as part of a range
| I682   | ambiguity of [end -n] as a matrix row vs index [end-n]
| I691   | a type is not given to the field which can be slow
| I692   | array field has no dimension which can be slow
|        |
| **I7** | *Style Info*
| I771   | type names should start with an upper case
