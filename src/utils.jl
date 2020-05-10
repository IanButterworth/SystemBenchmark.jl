using Pkg
function pkgversion()
    projecttoml_filename = joinpath(dirname(dirname(@__FILE__)),"Project.toml")
    projecttoml_parsed = Pkg.TOML.parse(read(projecttoml_filename, String))
    return VersionNumber(projecttoml_parsed["version"])
end

function readPrintedDataFrame(str::String)
    lines = split(str, "\n")
    if occursin("DataFrame",str)
        start = findfirst(occursin.("DataFrame", lines))
    else
        start = 1 #try first line
    end
    df = DataFrame(CSV.File(IOBuffer(str), delim="│", header=start+1, datarow=start+4))
    select!(df, Not([1,2,8]))
end
