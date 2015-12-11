Errors codes
============

| code | message |
|:----:|:--------|
|      |         |
|**E1**| *Parsing Error*
|      |         |
| E111 | failed to parse
| E112 | incomplete expression
| E121 | Lint does not understand
| E131 | Lint does not understand the variable as an function argument
| E132 | lint does not understand the variable as an lambda argument
| E133 | unknown keyword pattern
| E134 | unknown global pattern
| E135 | local declaration not understood by Lint
| E136 | Lint does not understand macro
| E137 | lintpragma must be called using only string literals
| E138 | incomplete pragma expression
| E139 | Lint fails to parse type: error
|      |         |
|      |         |
|**E2**| *Miscellaneous Error*
|      |         |
| E211 | deprecated message
| E221 | custum error
| E231 | expression: error; Signature: ...
|      |         |
|      |         |
|**E3**| *Existence Error*
|      |         |
| E311 | cannot find include file
| E321 | use of undeclared symbol
| E322 | exporting undefined symbol
| E331 | duplicate argument
| E332 | should not be used as a variable name
| E333 | duplicate exports of symbol
| E334 | duplicate key in Dict
|      |         |
|      |         |
|**E4**| *Usage Error*
|      |         |
| E411 | you cannot have non-default argument following default arguments
| E412 | named ellipsis ... can only be the last argument
| E413 | positional ellipsis ... can only be the last argument
| E414 | using is not allowed inside function definitions
| E415 | export is not allowed inside function definitions
| E416 | import is not allowed inside function definitions
| E417 | what is an anonymous function doing inside a type definition?
| E418 | RHS is a tuple of rhstype. N of variables used: len
| E418 | RHS is a tuple of rhstype. N of variables used: len
| E421 | use Union{...}, with curly, instead of parentheses
| E422 | string uses * to concatenate
| E423 | named keyword argument must have a default
| E424 | nested vect is treated as a 1-dimensional array. Use [a;b] instead
| E425 | use @lintpragma macro inside type declaration
| E431 | incorrect usage of length() in a Boolean context. You want to use isempty()
| E432 | though valid in 0.4, you want x() instead of y()
| E433 | for a decreasing range, use a negative step e.g. 10:-1:1
| E434 | value at position x is the referenced. Possible typo?
| E435 | new is provided with more arguments than fields
| E436 | more indices than dimensions
|      |         |
|      |         |
|**E5**| *Type Error*
|      |         |
| E511 | apparent non-Bool type
| E512 | lint doesn't understand expresion in a boolean context
| E513 | type is a leaf type. As a type constraint it makes no sense
| E514 | type is a leaf type. As a type constraint it makes no sense
| E516 | type assertion and default seem inconsistent
| E517 | constructor-like function X within type Y. Shouldn't they match?
| E518 | key type expects X, provided Y
| E519 | string[] expects Integer, provided X
| E521 | x has apparent type X, not a container type.
| E522 | macro arguments can only be Symbol/Expr
| E523 | constructor parameter (within curly brackets) collides with a type parameter
| E523 | constructor parameter (within curly brackets) collides with a type parameter
| E524 | bitstype needs its 2nd argument to be a new type symbol
| E525 | is of an immutable type
| E531 | multiple key types detected. Use Dict{Any,V}() for mixed type dict
| E532 | multiple value types detected. Use Dict{K,Any}() for mixed type dict
| E533 | type parameters in Julia are invariant, expression may not do what you want. Try f{T<:Number}(x::T)... 
| E534 | you mean {T<:X}? You are introducing it as a new name for an implicit argument to the function
| E535 | you mean {T<:X}? You are introducing it as a new name for an algebric data type
| E536 | you should use {T<:...} instead of a known type
| E537 | you want string(), i.e. string conversion, instead of a non-existent constructor
| E538 | you should use {T<:...} instead of a known type in parametric data type
|      |         |
|      |         |
|**E6**| *Structure Error*
|      |         |
| E611 | constructor doesn't seem to return the constructed object
| E611 | constructor doesn't seem to return the constructed object
|      |         |
|      |         |
|**W2**| *Miscellaneous Warning*
|      |         |
| W241 | custum warning
| W251 | expression: error; Symbol= X; rhstype= ...
|      |         |
|      |         |
|**W3**| *Existence Warning*
|      |         |
| W341 | local vars declared but not used
| W351 | you are redefining a mathematical constant
| W352 | lambda argument conflicts with a local variable. Best to rename
| W353 | lambda argument conflicts with an argument. Best to rename
| W354 | lambda argument conflicts with an declared global. Better to rename
| W355 | variable == function name
| W356 | local variable might cause confusion with a synonymous export from Base
|      |         |
|      |         |
|**W4**| *Usage Warning*
|      |         |
| W441 | probably illegal use of inside curly
| W442 | bit-wise in a boolean context. (&,|) do not have short-circuit behavior
| W443 | did you forget an -> after @doc or make it inline?
| W444 | nested vcat is treated as a 1-dimensional array
| W445 | nested hcat is treated as a 1-row horizontal array of dim=2
|      |         |
|      |         |
|**W5**| *Type Warning*
|      |         |
| W541 | doesn't eval into a Module
| W542 | comparing apparently incompatible types
| W543 | cannot determine if X is a DataType or not
| W544 | cannot determine if X is a DataType or not
| W545 | previously used variable has apparent type X, but now assigned Y
|      |         |
|      |         |
|**W6**| *Structure Warning*
|      |         |
| W641 | unreachable code after return
| W642 | true branch is unreachable
| W643 | false branch is unreachable
| W644 | redundant if-true statement
| W645 | while false block is unreachable
| W651 | the last of a expresion block looks different. Avg similarity score: X; Last part: Y
|      |         |
|      |         |
|**I1**| *Parsing Info*
|      |         |
| I171 | LHS in assignment not understood. please check expression
|      |         |
|      |         |
|**I2**| *Miscellaneous Info*
|      |         |
| I271 | custum info
|      |         |
|      |         |
|**I3**| *Existence Info*
|      |         |
| I371 | use of undeclared symbol
| I381 | unused @lintpragma
| I382 | argument declared but not used
| I391 | x is also a global, from src. Please check
|      |         |
|      |         |
|**I4**| *Usage Info*
|      |         |
| I471 | probably illegal use inside curly.
| I472 | assignment in the if-predicate clause.
| I473 | value at position x is the referenced y. OK if it represents permutations
| I474 | iteration generates tuples of rhstype. N of variables used: len
| I474 | iteration generates tuples of rhstype. N of variables used: len
| I481 | in 0.4+, replace x() with y()
| I482 | used in a local scope. Improve readability by using 'local' or another name
| I483 | {} may be deprecated. Use Any[]
| I484 | untyped dictionary {a=>b for (a,b) in c}, may be deprecated. Use (Any=>Any)[a=>b for (a,b) in c]
| I485 | untyped dictionary {a for a in c}, may be deprecated. Use (Any)[a for a in c]
| I486 | dictionary [a=>b,...], may be deprecated. Use @compat Dict(a=>b,...)
| I487 | (K=>V)[a=>b,...] may be deprecated. Use @compat Dict{K,V}(a=>b,...)
|      |         |
|      |         |
|**I5**| *Type Info*
|      |         |
| I571 | the 1st statement under the true-branch is a boolean expression. Typo?
| I572 | assert x type= X but assign a value of Y
| I581 | there is only 1 key type && 1 value type. Use explicit Dict{K,V}() for better performances
|      |         |
|      |         |
|**I6**| *Structure Info*
|      |         |
| I671 | new is provided with fewer arguments than fields
| I672 | iteration works for a number but it may be a typo
| I681 | ambiguity of :end as a symbol vs as part of a range
| I682 | ambiguity of [end -n] as a matrix row vs index [end-n]
| I691 | a type is not given to the field x, which can be slow
| I692 | array field x has no dimension, which can be slow
|      |         |
|      |         |
|**I7**| *Style Info*
|      |         |
| I771 | julia style recommends type names start with an upper cases
|      |         |
|      |         |
|      |         |
