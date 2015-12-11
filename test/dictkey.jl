s = """
@compat Dict(:a=>1, :b=>2, :a=>3)
"""
msgs = lintstr(s)
@test msgs[1].code == 334
@test contains(msgs[1].message, "duplicate key")
@test msgs[2].code == 581
@test contains(msgs[2].message, "there is only 1 key type && 1 value type. " *
    "Use explicit Dict{K,V}() for better performances")

s = """
@compat Dict(:a=>Date(2014, 1, 1), :b=>Date(2015, 1, 1))
"""
msgs = lintstr(s)
@test msgs[1].code == 581
@test contains(msgs[1].message, "there is only 1 key type && 1 value type. " *
    "Use explicit Dict{K,V}() for better performances")

s = """
@compat Dict{Symbol,Int}(:a=>1, :b=>"")
"""
msgs = lintstr(s)
@test msgs[1].code == 532
@test contains(msgs[1].message, "multiple value types detected")

s = """
@compat Dict{Symbol,Int}(:a=>1, "b"=>2)
"""
msgs = lintstr(s)
@test msgs[1].code == 531
@test contains(msgs[1].message, "multiple key types detected")
