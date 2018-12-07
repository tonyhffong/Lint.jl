s = """
Dict(:a=>1, :b=>2, :a=>3)
"""
msgs = lintstr(s)
@test msgs[1].code == :E334
@test occursin("duplicate key in Dict", msgs[1].message)

s = """
Dict{Symbol,Int}(:a=>1, :b=>"")
"""
msgs = lintstr(s)
@test msgs[1].code == :E532
@test occursin("multiple value types detected. Use Dict{K,Any}(, msgs[1].message) for " *
    "mixed type dict")

s = """
Dict{Symbol,Int}(:a=>1, "b"=>2)
"""
msgs = lintstr(s)
@test msgs[1].code == :E531
@test occursin("multiple key types detected. Use Dict{Any,V}(, msgs[1].message) for " *
    "mixed type dict")
