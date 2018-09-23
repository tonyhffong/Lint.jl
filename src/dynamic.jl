"""
Dynamically import the top-level module given by `sym`, and return it if
possible.
"""
function dynamic_import_toplevel_module(sym)::Union{Module, Nothing}
    info("dynamic import: $sym")
    try
        eval(Main, :(import $sym))
        getfield(Main, sym)
    catch
        nothing
    end
end
