module SystemBenchmark
using BenchmarkTools
using CuArrays
using CSV
using DataFrames
using InteractiveUtils
using Logging
using ProgressMeter
using VideoIO

export sysbenchmark, compare, compareToRef, saveBenchmark, readBenchmark

function getSystemInfo()
    buf = PipeBuffer()
    InteractiveUtils.versioninfo(buf, verbose=false)
    systeminfo = read(buf, String)
    CuArrays.functional() && (systeminfo *= string("  GPU: $(CuArrays.CUDAdrv.name(CuArrays.CUDAdrv.device()))"))
    return systeminfo
end

function saveBenchmark(path::String, res::DataFrame)
    systeminfo = getSystemInfo()
    open(path, "w") do io
        println(io, systeminfo)
        println(io, "--INFO END--")
        println(io,"cat,testname,ms")
        CSV.write(io, res, append=true)
    end
end
function readBenchmark(path::String)
    lines = readlines(path)
    divider = findfirst(occursin.("--INFO END--",lines))
    s = open(f->read(f, String), path)
    systeminfo = split(s,"--INFO END--")[1]
    res = DataFrame(CSV.File(path, skipto=divider+2, header=divider+1))
    return systeminfo, res
end

function compare(ref::DataFrame, test::DataFrame)
	df = DataFrame(cat=String[], testname=String[], ref_ms=Float64[], res_ms=Float64[], factor=Float64[])
	for testname in unique(test.testname)
		testrow = test[test.testname .== testname, :]
		refrow = ref[ref.testname .== testname, :]
    	push!(df, Dict(:cat=>testrow.cat[1], 
			:testname=>testname, 
			:ref_ms=>refrow.ms[1], 
			:res_ms=>testrow.ms[1], 
			:factor=>testrow.ms[1] ./ refrow.ms[1]
			))
	end
	return df
end

function compare(ref_sysinfo::String, ref::DataFrame, test_sysinfo::String, test::DataFrame)
    println("Reference system ----------------------")
    println(ref_sysinfo)
    println("Test system ---------------------------")
    println(test_sysinfo)
    println("")
	df = DataFrame(cat=String[], testname=String[], ref_ms=Float64[], test_ms=Float64[], factor=Float64[])
	for testname in unique(test.testname)
		testrow = test[test.testname .== testname, :]
		refrow = ref[ref.testname .== testname, :]
    	push!(df, Dict(:cat=>testrow.cat[1], 
			:testname=>testname, 
			:ref_ms=>refrow.ms[1], 
			:test_ms=>testrow.ms[1], 
			:factor=>testrow.ms[1] ./ refrow.ms[1]
			))
	end
	return df
end

compareToRef() = compareToRef(sysbenchmark())

function compareToRef(test::DataFrame; refname="1-linux-i7-2.6GHz-GTX1650.txt")
    test_sysinfo = getSystemInfo()
    ref_sysinfo, ref = readBenchmark(joinpath(dirname(@__DIR__), "ref", refname))
    return compare(string(ref_sysinfo), ref, test_sysinfo, test)
end

function sysbenchmark()
    ntests = 12
    systeminfo = getSystemInfo()

    if CuArrays.functional()
        ntests += 1
    else
        @info "CuArrays.functional() == false. No usable GPU detected"
    end

    df = DataFrame(cat=String[], testname=String[], ms=Float64[])
    prog = ProgressMeter.Progress(ntests) 
    prog.desc = "CPU tests"
    t = @benchmark x * x setup=(x=rand()); append!(df, DataFrame(cat="cpu", testname="FloatMul", ms=median(t).time / 1e6)); next!(prog)
    t = @benchmark sin(x) setup=(x=rand()); append!(df, DataFrame(cat="cpu", testname="FloatSin", ms=median(t).time / 1e6)); next!(prog)
    t = @benchmark x .* x setup=(x=rand(10)); append!(df, DataFrame(cat="cpu", testname="VecMulBroad", ms=median(t).time / 1e6)); next!(prog)
    t = @benchmark x * x setup=(x=rand(Float32, 100, 100)); append!(df, DataFrame(cat="cpu", testname="MatMul", ms=median(t).time / 1e6)); next!(prog)
    t = @benchmark x .* x setup=(x=rand(Float32, 100, 100)); append!(df, DataFrame(cat="cpu", testname="MatMulBroad", ms=median(t).time / 1e6)); next!(prog)
    t = @benchmark x .* x setup=(x=rand(10,10,10)); append!(df, DataFrame(cat="cpu", testname="3DMulBroad", ms=median(t).time / 1e6)); next!(prog)
    t = @benchmark writevideo(imgstack) setup=(imgstack=map(x->rand(UInt8,100,100), 1:100)); append!(df, DataFrame(cat="cpu", testname="FFMPEGH264Write", ms=median(t).time / 1e6)); next!(prog)
    
    if CuArrays.functional()
        prog.desc = "GPU tests"
        x=cu(rand(Float32,100,100))
        t = @benchmark $x * $x; append!(df, DataFrame(cat="gpu", testname="MatMul", ms=median(t).time / 1e6)); next!(prog)
    end

    prog.desc = "Memory tests"
    t = @benchmark deepcopy(x) setup=(x=rand(UInt8,1000)); append!(df, DataFrame(cat="mem", testname="DeepCopy", ms=median(t).time / 1e6)); next!(prog)
    
    prog.desc = "Disk IO tests"
    t = @benchmark tempwrite(x) setup=(x=rand(UInt8,1000)); append!(df, DataFrame(cat="diskio", testname="TempdirWrite", ms=median(t).time / 1e6)); next!(prog)
    t = @benchmark tempread(path) setup=(path = tempwrite(rand(UInt8,1000), false)); append!(df, DataFrame(cat="diskio", testname="TempdirRead", ms=median(t).time / 1e6)); next!(prog)
    
    prog.desc = "Julia loading tests"
    t = @benchmark runjulia("1+1"); append!(df, DataFrame(cat="loading", testname="JuliaLoad", ms=median(t).time / 1e6)); next!(prog)
    juliatime = median(t).time / 1e6

    prog.desc = "Compilation tests"
    insert!(LOAD_PATH, 1, @__DIR__); insert!(DEPOT_PATH, 1, mktempdir())
    Logging.disable_logging(Logging.Info)
    t = @benchmark Base.compilecache(Base.PkgId("ExampleModule")); append!(df, DataFrame(cat="compilation", testname="compilecache", ms=(median(t).time / 1e6)-juliatime)); next!(prog)
    Logging.disable_logging(Logging.Debug)
    deleteat!(LOAD_PATH,1); deleteat!(DEPOT_PATH,1)

    finish!(prog)
    println(systeminfo)
    return df
end
## CPU
function writevideo(imgstack, delete::Bool=true)
    path, io = mktemp()
    VideoIO.encodevideo("$path.mp4", imgstack, silent=true)
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
    x = read(io)
    close(io)
    return x
end
## Julia Loading
function runjulia(e)
    juliabin = joinpath(Sys.BINDIR, Base.julia_exename())
    run(`$(joinpath(Sys.BINDIR, Base.julia_exename())) --project=$(dirname(@__DIR__)) --startup-file=no -e "$e"`)
end
end #module