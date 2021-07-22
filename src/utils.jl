using Pkg
using GitHub
using DataFrames
using Downloads

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
    df = DataFrame(CSV.File(IOBuffer(str), delim="│", header=start, datarow=start+4))
    select!(df, Not([1,2,length(names(df))]))
    names!(df,Symbol.(strip.(names(df))))
    df[!,:cat] = string.(strip.(df[:cat]))
    df[!,:testname] = string.(strip.(df[:testname]))
    df[!,:res] = string.(strip.(df[:res]))
    return df
end

function getsubmittedbenchmarks(;repo::String="IanButterworth/SystemBenchmark.jl", issue::Int=8,
                    refname::String="ref.txt", transpose::Bool=true, authkey=get(ENV,"PERSONAL_ACCESS_TOKEN",nothing))

    if !isnothing(authkey)
        auth = GitHub.authenticate(authkey)
        comments = GitHub.comments(repo, issue, :issue, auth=auth)[1]
    else
        comments = GitHub.comments(repo, issue, :issue)[1]
    end
    i = 1
    ref = readbenchmark(joinpath(dirname(@__DIR__), "ref", refname))
    master_res = DataFrame(cat=["info","info"],testname=["user","datetime"],units=Union{String,Missing}[missing,missing],res=["ref","2020-05-10"])
    append!(master_res, ref)
    rename!(master_res, [:cat,:testname,:units,:ref])
    files = map(comment->map(x->string(x.match), collect(eachmatch(r"https:\/\/github\.com\/.*\.txt",comment.body, overlap=false))),comments)
    nresults = sum(length.(files))
    filter!(x->occursin(r"https:\/\/github\.com\/.*\.txt", x.body), comments)
    prog = Progress(nresults, desc = "Downloading $(nresults) results... ")
    filedict = Dict{String,String}()
    @sync for comment in comments
        resulturls = map(x->string(x.match), collect(eachmatch(r"https:\/\/github\.com\/.*\.txt",comment.body, overlap=false)))
        for resulturl in resulturls
            @async begin
                filedict[resulturl] = Downloads.download(resulturl)
                next!(prog)
            end
        end
    end
    for comment in comments
        resulturls = map(x->string(x.match), collect(eachmatch(r"https:\/\/github\.com\/.*\.txt",comment.body, overlap=false)))
        for resulturl in resulturls
            username = "@$(comment.user.login)"
            datetime = comment.updated_at
            file = filedict[resulturl]
            res = readbenchmark(file)
            if ("units" in names(res))
                "test_res" in names(res) && (res = DataFrame(cat=res.cat, testname=res.testname, units=res.units, res=res.test_res))
                res_formatted = DataFrame(cat=["info","info"],testname=["user","datetime"],units=Union{String,Missing}[missing,missing],res=[username,datetime])
                append!(res_formatted, res)
                rename!(res_formatted, [:cat,:testname,:units,Symbol("res_$i")])
                master_res = DataFrames.outerjoin(master_res, res_formatted, on = [:cat,:units,:testname], matchmissing=:equal)
            else
                "test_res" in names(res) && (res = DataFrame(cat=res.cat, testname=res.testname, res=res.test_res))
                res_formatted = DataFrame(cat=["info","info"],testname=["user","datetime"],res=[username,datetime])
                append!(res_formatted, res)
                rename!(res_formatted, [:cat,:testname,Symbol("res_$i")])
                master_res = DataFrames.outerjoin(master_res, res_formatted, on = [:cat,:testname], matchmissing=:equal)
            end
            i += 1
            next!(prog)
        end
    end
    if transpose
        return restranspose(master_res)
    else
        return master_res
    end
end
function restranspose(res::DataFrame)
    resfilt = res[:,4:end]
    rows =  collect.(eachrow(resfilt))
    i = 1
    for c in res.cat
        if c != "info"
            rows[i] = map(x->ismissing(x) ? missing : parse(Float64,x),rows[i])
        end
        i += 1
    end
    df = DataFrame([[names(resfilt)]; rows], [:resultid; Symbol.(res.testname)])
    return df
end
