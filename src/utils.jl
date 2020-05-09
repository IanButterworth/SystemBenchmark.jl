using Pkg
function pkgversion()
    projecttoml_filename = joinpath(dirname(dirname(@__FILE__)),"Project.toml")
    projecttoml_parsed = Pkg.TOML.parse(read(projecttoml_filename, String))
    return VersionNumber(projecttoml_parsed["version"])
end