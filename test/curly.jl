s = """
a = Dict{:Symbol, Any}
"""
msgs = lintstr(s)
@test msgs[1].code == :W447
@test contains(msgs[1].message, "type parameter for Dict")

s = """
a = Dict{:Symbol, Any}()
"""
msgs = lintstr(s)
@test msgs[1].code == :W447
@test contains(msgs[1].message, "type parameter for Dict")

s = """
a = Set{Tuple{Int, Int}}()
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
a = Set{(Int, Int)}()
"""
msgs = lintstr(s)
@test msgs[1].code == :W441
@test contains(msgs[1].message, "probably illegal use inside curly")

s = """
b = :Symbol
a = Dict{b, Any}()
"""
msgs = lintstr(s)
@test msgs[1].code == :W447
@test contains(msgs[1].message, "type parameter for Dict")

s = """
a = Array{2, Int64}()
"""
msgs = lintstr(s)
@test msgs[1].code == :W447
@test contains(msgs[1].message, "type parameter for Array")

s = """
a = Array{Int64, 5, 5}()
"""
msgs = lintstr(s)
@test msgs[1].code == :W446
@test contains(msgs[1].message, "too many type parameters")

s = """
a = Ptr{Void}
"""
msgs = lintstr(s)
@test isempty(msgs)

s = """
@traitfn ft1{X,Y; Cmp{X,Y}}(x::X,y::Y) = x > y ? 5 : 6
"""
msgs = lintstr(s)
@test isempty(msgs)
