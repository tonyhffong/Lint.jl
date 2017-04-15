"""
Dynamically import the top-level module given by `sym`, and return it if
possible.
"""
function dynamic_import_toplevel_module(sym)::Nullable{Module}
    try
        eval(Main, :(import $sym))
        Nullable(getfield(Main, sym))
    catch
        Nullable()
    end
end
