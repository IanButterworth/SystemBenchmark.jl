module SystemBenchmark

using BenchmarkTools
using CSV
using DataFrames

export sysbenchmark, compare, compareToRef

function sysbenchmark()
    df = DataFrame(cat=String[], testname=String[], ms=Float64[])

    @info "CPU tests"
    t = @benchmark x * x setup=(x=rand()); append!(df, DataFrame(cat="cpu", testname="FloatMul", ms=median(t).time / 1e6))
    t = @benchmark sin(x) setup=(x=rand()); append!(df, DataFrame(cat="cpu", testname="FloatSin", ms=median(t).time / 1e6))
    t = @benchmark x .* x setup=(x=rand(10)); append!(df, DataFrame(cat="cpu", testname="VecMulBroad", ms=median(t).time / 1e6))
    t = @benchmark x * x setup=(x=rand(10,10)); append!(df, DataFrame(cat="cpu", testname="MatMul", ms=median(t).time / 1e6))
    t = @benchmark x .* x setup=(x=rand(10,10)); append!(df, DataFrame(cat="cpu", testname="MatMulBroad", ms=median(t).time / 1e6))
    t = @benchmark x .* x setup=(x=rand(10,10,10)); append!(df, DataFrame(cat="cpu", testname="3DMulBroad", ms=median(t).time / 1e6))
    
    @info "Memory tests"
    t = @benchmark deepcopy(x) setup=(x=rand(UInt8,1000)); append!(df, DataFrame(cat="mem", testname="DeepCopy", ms=median(t).time / 1e6))
    
    @info "Disk IO tests"
    t = @benchmark tempwrite(x) setup=(x=rand(UInt8,1000)); append!(df, DataFrame(cat="diskio", testname="TempdirWrite", ms=median(t).time / 1e6))
    t = @benchmark tempread(path) setup=(path = tempwrite(rand(UInt8,1000), false)); append!(df, DataFrame(cat="diskio", testname="TempdirRead", ms=median(t).time / 1e6))
    
    @info "Julia loading tests"
    t = @benchmark run(`$binpath --startup-file=no -e "1+1"`) setup=(binpath=joinpath(Sys.BINDIR, Base.julia_exename())); append!(df, DataFrame(cat="loading", testname="JuliaLoad", ms=median(t).time / 1e6))
    t = @benchmark run(`$binpath --startup-file=no -e "using CSV"`) setup=(binpath=joinpath(Sys.BINDIR, Base.julia_exename())); append!(df, DataFrame(cat="loading", testname="UsingCSV", ms=median(t).time / 1e6))
    
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
end #module