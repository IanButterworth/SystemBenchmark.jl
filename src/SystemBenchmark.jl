module SystemBenchmark

using BenchmarkTools
using CSV
using DataFrames
using ProgressMeter
using VideoIO

export sysbenchmark, compare, compareToRef

function sysbenchmark()
    df = DataFrame(cat=String[], testname=String[], ms=Float64[])
    prog = Progress(10)

    prog.desc = "CPU tests"
    t = @benchmark x * x setup=(x=rand()); append!(df, DataFrame(cat="cpu", testname="FloatMul", ms=median(t).time / 1e6)); next!(prog)
    t = @benchmark sin(x) setup=(x=rand()); append!(df, DataFrame(cat="cpu", testname="FloatSin", ms=median(t).time / 1e6)); next!(prog)
    t = @benchmark x .* x setup=(x=rand(10)); append!(df, DataFrame(cat="cpu", testname="VecMulBroad", ms=median(t).time / 1e6)); next!(prog)
    t = @benchmark x * x setup=(x=rand(10,10)); append!(df, DataFrame(cat="cpu", testname="MatMul", ms=median(t).time / 1e6)); next!(prog)
    t = @benchmark x .* x setup=(x=rand(10,10)); append!(df, DataFrame(cat="cpu", testname="MatMulBroad", ms=median(t).time / 1e6)); next!(prog)
    t = @benchmark x .* x setup=(x=rand(10,10,10)); append!(df, DataFrame(cat="cpu", testname="3DMulBroad", ms=median(t).time / 1e6)); next!(prog)
    t = @benchmark writevideo(imgstack) setup=(imgstack=map(x->rand(UInt8,100,100), 1:100)); append!(df, DataFrame(cat="cpu", testname="FFMPEGH264Write", ms=median(t).time / 1e6)); next!(prog)
    
    prog.desc = "Memory tests"
    t = @benchmark deepcopy(x) setup=(x=rand(UInt8,1000)); append!(df, DataFrame(cat="mem", testname="DeepCopy", ms=median(t).time / 1e6)); next!(prog)
    
    prog.desc = "Disk IO tests"
    t = @benchmark tempwrite(x) setup=(x=rand(UInt8,1000)); append!(df, DataFrame(cat="diskio", testname="TempdirWrite", ms=median(t).time / 1e6)); next!(prog)
    t = @benchmark tempread(path) setup=(path = tempwrite(rand(UInt8,1000), false)); append!(df, DataFrame(cat="diskio", testname="TempdirRead", ms=median(t).time / 1e6)); next!(prog)
    
    prog.desc = "Julia loading tests"
    
    t = @benchmark runjulia("1+1"); append!(df, DataFrame(cat="loading", testname="JuliaLoad", ms=median(t).time / 1e6))
    juliatime = median(t).time / 1e6
    t = @benchmark runjulia("using CSV"); append!(df, DataFrame(cat="loading", testname="UsingCSV", ms=(median(t).time / 1e6)-juliatime))
    t = @benchmark runjulia("using VideoIO"); append!(df, DataFrame(cat="loading", testname="UsingVideoIO", ms=(median(t).time / 1e6)-juliatime))
    
    return df
end

function compare(res1::DataFrame, res2::DataFrame)
    @assert res1.testname == res2.testname "Testsuites seem to be different"
    return DataFrame(cat=res1.cat, testname=res1.testname, res1_ms=res1.ms, res2_ms=res2.ms, factor=res2.ms ./ res1.ms)
end

function compareToRef(res2::DataFrame; refname="1-2018MBP_MacOS.csv")
    res1 = CSV.read(joinpath(dirname(@__DIR__), "ref", refname))
    return compare(res1, res2)
end

## CPU
function writevideo(imgstack, delete::Bool=true)
    path, io = mktemp()
    encodevideo("$path.mp4", imgstack, silent=true)
    delete && rm(path)
    return path
end


## DiskIO
function tempwrite(x, delete::Bool=true)
    path, io = mktemp()
    write(io, x)
    close(io)
    delete && rm(path)
    return path
end
function tempread(path)
    io = open(path)
    read(io)
    close(io)
end

## Julia Loading
function runjulia(e)
    run(`$(joinpath(Sys.BINDIR, Base.julia_exename())) --project=$(dirname(@__DIR__)) --startup-file=no -e "$e"`)
end
end #module