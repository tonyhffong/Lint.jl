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
