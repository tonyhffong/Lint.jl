s = """
import Base: show
"""
msgs = lintstr( s )
@assert( isempty( msgs ) )

s = """
importall Lint
"""
msgs = lintstr( s )
@assert( isempty( msgs ) )
