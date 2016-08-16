s = """[i for i in 1:2]
"""
msgs = lintstr(s)
@test isempty(msgs)

s = if VERSION ≥ v"0.5.0-"
    """
    Dict(j => j*j for j in 1:2)
    """
else
    """
    [j => j*j for j in 1:2]
    """
end
msgs = lintstr(s)
@test isempty(msgs)

s = if VERSION ≥ v"0.5.0-"
    """
    Dict{Int,Int}(y2 => y2*y2 for y2 in 1:2)
    """
else
    """
    (Int=>Int)[y2 => y2*y2 for y2 in 1:2]
    """
end
msgs = lintstr(s)
@test isempty(msgs)
