s = """
import Base: show
import Base.Math
"""
msgs = lintstr( s )
@assert( isempty( msgs ) )

s = """
importall Lint
"""
msgs = lintstr( s )
@assert( isempty( msgs ) )
