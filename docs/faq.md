# Frequently Asked Questions

## What can Lint.jl find?
* [What can it find](features/#what-can-it-find).
* [List of errors](messages/#errors-codes).


## Lint is giving me a false positive. What should I do?
If Lint.jl is giving you a warning that you disagree with you have 2 choices:

* You can tell Lint.jl to [ignore the error](features/#ignoring-messages).
* If you feel it is a bug then [report the issue](https://github.com/tonyhffong/Lint.jl/issues).


## Editor and IDE integrations?
See [lintserver feature](features/#lintserver).


## What versions of julia is Lint.jl supporting?
The focus of Lint.jl is to support the current release and then to follow closely the development version as best as we can. You may have to use older versions of Lint.jl for older code.


## Is it possible to locally disable a particular message?
See [@lintpragma](features/#lintpragma-steering-lint-time-behavior).


## Is there a way to disable a particular message when linting?
See [ignoring messages](features/#ignoring-messages).
