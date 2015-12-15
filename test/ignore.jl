s = """
declared_elsewhere
"""
msgs = lintstr(s, LintContext("none", ignore=[LintIgnore(:E321, "declared_elsewhere")]))
@test isempty(msgs)
