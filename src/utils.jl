using Pkg
using GitHub
using DataFrames

function pkgversion()
    projecttoml_filename = joinpath(dirname(dirname(@__FILE__)),"Project.toml")
    projecttoml_parsed = Pkg.TOML.parse(read(projecttoml_filename, String))
    return VersionNumber(projecttoml_parsed["version"])
end

function readprinteddataframe(str::String)
    lines = split(str, "\n")
    if occursin("DataFrame",str)
        start = findfirst(occursin.("DataFrame", lines))
    else
        start = 1 #try first line
    end
    df = DataFrame(CSV.File(IOBuffer(str), delim="│", header=start+1, datarow=start+4))
    select!(df, Not([1,2,8]))
end

function getsubmittedbenchmarks(repo::String="ianshmean/SystemBenchmark.jl",issue::Int=8, refname="ref.txt")
    comments = GitHub.comments(repo, issue, :issue)[1]
    results = DataFrame[]
    i = 1
    ref = readbenchmark(joinpath(dirname(@__DIR__), "ref", refname))
    master_res = DataFrame(cat=["info","info"],testname=["user","datetime"],res=["ref","2020-05-10"])
    append!(master_res, ref)
    rename!(master_res, [:cat,:testname,:ref])
    for comment in comments
        if occursin(".txt", comment.body) && occursin("https://github.com/$repo/files/", comment.body)
            resulturl =  string("https://github.com/$repo/files/", split(split(comment.body,"https://github.com/$repo/files/")[2],".txt")[1],".txt")
            username = "@$(comment.user.login)"
            datetime = comment.updated_at
            file = download(resulturl)
            res = readbenchmark(file)
            if "test_res" in names(res)
                res = DataFrame(cat=res.cat, testname=res.testname, res=res.test_res)
            end
            res_formatted = DataFrame(cat=["info","info"],testname=["user","datetime"],res=[username,datetime])
            append!(res_formatted, res)
            rename!(res_formatted, [:cat,:testname,Symbol("res_$i")])
            master_res = DataFrames.innerjoin(master_res, res_formatted, on = [:cat,:testname])
            i += 1
        end
    end
    return master_res
end
