module LintCompat

export BROADCAST, flatten

# TODO: remove when 0.5 support dropped
function BROADCAST(f, x::Nullable)
    if isnull(x)
        Nullable()
    else
        Nullable(f(get(x)))
    end
end

# TODO: move to a different repository
"""
    flatten(f, x::Nullable{<:Nullable}) :: Nullable

Unwrap one layer of a two-layed `Nullable` object.

Often combined with broadcast as in `flatten(broadcast(f, x))`, which is like
`broadcast(f, x)`, except returns the result of `f` directly. Expects `f` to
return a `Nullable` value.
"""
function flatten{T}(x::Nullable{Nullable{T}})
    if isnull(x)
        Nullable{T}()
    else
        get(x)
    end
end

# fallback method for e.g. Nullable{Any}, Nullable{Union{}}
function flatten(x::Nullable)
    if isnull(x)
        Nullable()
    else
        get(x) :: Nullable
    end
end

end
