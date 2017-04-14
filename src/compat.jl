module LintCompat

export BROADCAST

# TODO: remove when 0.5 support dropped
function BROADCAST(f, x::Nullable)
    if isnull(x)
        Nullable()
    else
        Nullable(f(get(x)))
    end
end

end
