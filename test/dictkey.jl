s = """
Dict(:a=>1, :b=>2, :a=>3)
"""
msgs = lintstr(s)
@test msgs[1].code == :E334
@test occursin(msgs[1].message, "duplicate key in Dict")

s = """
Dict{Symbol,Int}(:a=>1, :b=>"")
"""
msgs = lintstr(s)
@test msgs[1].code == :E532
@test occursin(msgs[1].message, "multiple value types detected. Use Dict{K,Any}() for " *
    "mixed type dict")

s = """
Dict{Symbol,Int}(:a=>1, "b"=>2)
"""
msgs = lintstr(s)
@test msgs[1].code == :E531
@test occursin(msgs[1].message, "multiple key types detected. Use Dict{Any,V}() for " *
    "mixed type dict")
