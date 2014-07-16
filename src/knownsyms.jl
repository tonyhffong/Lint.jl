const knownsyms = Set{Symbol}()
union!( knownsyms, names( Core ) )
union!( knownsyms, names( Base ) )
union!( knownsyms, [
 symbol( "end" ),
 symbol( "Entry" ),
 :STDIN,
 :STDOUT,
 :box,
 :tupleref,
 :apply_type,
 :pointerset,
 :arraysize,
 ] )

const knowntypes = Set{Symbol}()
union!( knowntypes, filter( names( Base ) ) do x
    ok = false
    try
        ok = isa( eval( Base, x ), DataType )
    end
end)
union!( knowntypes, filter( names( Core ) ) do x
    ok = false
    try
        ok = isa( eval( Core, x ), DataType )
    end
end)
