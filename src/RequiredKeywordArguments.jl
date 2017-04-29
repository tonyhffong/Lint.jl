module RequiredKeywordArguments

using Base.Meta
export @required

"""
    @required(arg)
    @required(arg::Type)

Indicates that the given keyword argument is required; that is, an
`ArgumentError` will be thrown if it is not provided.
"""
macro required(ex)
    target = if isexpr(ex, :(::))
        ex.args[1]
    elseif isa(ex, Symbol)
        ex
    else
        throw(ArgumentError("@required($ex) does not match expected format"))
    end

    # TODO: fix when 0.5 support dropped
    # This is the right code, but it doesn't work on 0.5, so we make do with
    # the wronger version.
#    Expr(:kw, esc(ex),
#         :(throw(ArgumentError($"keyword argument $target is required"))))
    esc(Expr(:kw, ex,
             :(throw(ArgumentError($"keyword argument $target is required")))))
end

end
