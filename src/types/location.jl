@auto_hash_equals struct Location
    file::String
    line::Int
end
file(loc::Location) = loc.file
line(loc::Location) = loc.line
file(x) = file(location(x))
line(x) = line(location(x))
function Base.show(io::IO, loc::Location)
    if loc == UNKNOWN_LOCATION
        print(io, "unknown")
    else
        print(io, file(loc), ":", line(loc))
    end
end

const UNKNOWN_LOCATION = Location("unknown", -1)
