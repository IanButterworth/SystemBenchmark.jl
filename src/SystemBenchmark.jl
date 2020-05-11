module SystemBenchmark
using BenchmarkTools
using CuArrays
using CSV
using DataFrames
using InteractiveUtils
using LinearAlgebra
using Logging
using ProgressMeter
using VideoIO

include("utils.jl")

export runbenchmark, compare, comparetoref, savebenchmark, readbenchmark, getsubmittedbenchmarks

const HAS_GPU = Ref{Bool}(false)

function __init__()
    HAS_GPU[] = CuArrays.functional()
end

function getinfofield(info::String, field::String)::String
    value = split(info, field)[2]
    return string(strip(split(value,"\n")[1]))
end

function getsysteminfo()
    buf = PipeBuffer()
    InteractiveUtils.versioninfo(buf, verbose=false)
    systeminfo = read(buf, String)
    
    df = DataFrame(cat=String[], testname=String[], res=Any[])
    push!(df, ["info","SysBenchVer",string(pkgversion())])
    push!(df, ["info","JuliaVer",getinfofield(systeminfo, "Julia Version")])
    push!(df, ["info","OS",getinfofield(systeminfo, "OS:")])
    push!(df, ["info","CPU",getinfofield(systeminfo, "CPU:")])
    push!(df, ["info","WORD_SIZE",getinfofield(systeminfo, "WORD_SIZE:")])
    push!(df, ["info","LIBM",getinfofield(systeminfo, "LIBM:")])
    push!(df, ["info","LLVM",getinfofield(systeminfo, "LLVM:")])
    if HAS_GPU[] 
        push!(df, ["info","GPU",CuArrays.CUDAdrv.name(CuArrays.CUDAdrv.device())])
    else
        push!(df, ["info","GPU",missing])
    end
    return df
end

function savebenchmark(path::String, res::DataFrame)
    open(path, "w") do io
        CSV.write(io, res)
    end
end
function readbenchmark(path::String)
    return DataFrame(CSV.File(path))
end

function compare(ref::DataFrame, test::DataFrame)
	df = DataFrame(cat=String[], testname=String[], ref_res=Any[], test_res=Any[], factor=Any[])
    for testname in unique(test.testname)
		testrow = test[test.testname .== testname, :]
        refrow = ref[ref.testname .== testname, :]
        if testrow.cat[1] == "info"
            if ismissing(refrow.res[1] != testrow.res[1]) || (refrow.res[1] != testrow.res[1])
                factor = "Not Equal"
            else
                factor = "Equal"
            end
            push!(df, Dict(:cat=>testrow.cat[1], 
                :testname=>testname, 
                :ref_res=>refrow.res[1], 
                :test_res=>testrow.res[1], 
                :factor=>factor
                ))
        else
            testres = typeof(testrow.res[1]) == String ? parse(Float64,testrow.res[1]) : testrow.res[1]
            refres = typeof(refrow.res[1]) == String ? parse(Float64,refrow.res[1]) : refrow.res[1]
            push!(df, Dict(:cat=>testrow.cat[1], 
                :testname=>testname, 
                :ref_res=>refrow.res[1], 
                :test_res=>testrow.res[1], 
                :factor=>testres / refres
                ))
        end
	end
	return df
end

comparetoref() = comparetoref(runbenchmark(printsysinfo = false))

function comparetoref(test::DataFrame; refname="ref.txt")
    ref = readbenchmark(joinpath(dirname(@__DIR__), "ref", refname))
    return compare(ref, test)
end

function runbenchmark(;printsysinfo = true)
    ntests = 18
    if HAS_GPU[]
        ntests += 1
    else
        @info "CuArrays.functional() == false. No usable GPU detected"
    end

    df = getsysteminfo() #initialize DataFrame with system info 
    prog = ProgressMeter.Progress(ntests) 
    prog.desc = "CPU tests"; ProgressMeter.updateProgress!(prog)
    t = @benchmark x * x setup=(x=rand()); append!(df, DataFrame(cat="cpu", testname="FloatMul", res=median(t).time / 1e6)); next!(prog)
    t = @benchmark a * b + c setup=(a=rand(); b=rand(); c=rand()); append!(df, DataFrame(cat="cpu", testname="FusedMulAdd", res=median(t).time / 1e6)); next!(prog)
    t = @benchmark sin(x) setup=(x=rand()); append!(df, DataFrame(cat="cpu", testname="FloatSin", res=median(t).time / 1e6)); next!(prog)
    t = @benchmark x .* x setup=(x=rand(10)); append!(df, DataFrame(cat="cpu", testname="VecMulBroad", res=median(t).time / 1e6)); next!(prog)
    t = @benchmark x * x setup=(x=rand(Float32, 100, 100)); append!(df, DataFrame(cat="cpu", testname="CPUMatMul", res=median(t).time / 1e6)); next!(prog)
    t = @benchmark x .* x setup=(x=rand(Float32, 100, 100)); append!(df, DataFrame(cat="cpu", testname="MatMulBroad", res=median(t).time / 1e6)); next!(prog)
    t = @benchmark x .* x setup=(x=rand(10,10,10)); append!(df, DataFrame(cat="cpu", testname="3DMulBroad", res=median(t).time / 1e6)); next!(prog)
    append!(df, DataFrame(cat="cpu", testname="peakflops", res=LinearAlgebra.peakflops())); next!(prog)
   
    t = @benchmark writevideo(imgstack) setup=(imgstack=map(x->rand(UInt8,100,100), 1:100)); append!(df, DataFrame(cat="cpu", testname="FFMPEGH264Write", res=median(t).time / 1e6)); next!(prog)
    isfile(joinpath(@__DIR__, "testvideo.mp4")) && rm(joinpath(@__DIR__, "testvideo.mp4"))

    if HAS_GPU[]
        prog.desc = "GPU tests"; ProgressMeter.updateProgress!(prog)
        x=cu(rand(Float32,100,100))
        t = @benchmark $x * $x; append!(df, DataFrame(cat="gpu", testname="GPUMatMul", res=median(t).time / 1e6)); next!(prog)
    end

    prog.desc = "Memory tests"; ProgressMeter.updateProgress!(prog)
    t = @benchmark deepcopy(x) setup=(x=rand(UInt8,1000)); append!(df, DataFrame(cat="mem", testname="DeepCopy", res=median(t).time / 1e6)); next!(prog)
    
    prog.desc = "Disk IO tests"; ProgressMeter.updateProgress!(prog)
    t = @benchmark tempwrite(x) setup=(x=rand(UInt8,1000)); append!(df, DataFrame(cat="diskio", testname="DiskWrite1KB", res=median(t).time / 1e6)); next!(prog)
    t = @benchmark tempwrite(x) setup=(x=rand(UInt8,1000000)); append!(df, DataFrame(cat="diskio", testname="DiskWrite1MB", res=median(t).time / 1e6)); next!(prog)
    t = @benchmark tempread(path) setup=(path = tempwrite(rand(UInt8,1000), delete=false)); append!(df, DataFrame(cat="diskio", testname="DiskRead1KB", res=median(t).time / 1e6)); next!(prog)
    isfile(joinpath(@__DIR__, "testwrite.dat")) && rm(joinpath(@__DIR__, "testwrite.dat"))
    t = @benchmark tempread(path) setup=(path = tempwrite(rand(UInt8,1000000), delete=false)); append!(df, DataFrame(cat="diskio", testname="DiskRead1MB", res=median(t).time / 1e6)); next!(prog)
    isfile(joinpath(@__DIR__, "testwrite.dat")) && rm(joinpath(@__DIR__, "testwrite.dat"))
    

    prog.desc = "Julia loading tests"; ProgressMeter.updateProgress!(prog)
    t = @benchmark runjulia("1+1"); append!(df, DataFrame(cat="loading", testname="JuliaLoad", res=median(t).time / 1e6)); next!(prog)
    juliatime = median(t).time / 1e6

    prog.desc = "Compilation tests"; ProgressMeter.updateProgress!(prog)
    insert!(LOAD_PATH, 1, @__DIR__); insert!(DEPOT_PATH, 1, mktempdir())
    Logging.disable_logging(Logging.Info)
    pkg = Base.PkgId("ExampleModule")
    t = @benchmark Base.compilecache($pkg); append!(df, DataFrame(cat="compilation", testname="compilecache", res=(median(t).time / 1e6))); next!(prog)
    path, cachefile, concrete_deps = compilecache_init(pkg)
    Logging.disable_logging(Logging.Debug)
    deleteat!(LOAD_PATH,1); deleteat!(DEPOT_PATH,1)

    # calling create_expr_cache rapidly on windows seems to cause a LLVM malloc issue, so slowGC() is used as a teardown to slow the process
    t = @benchmark Base.create_expr_cache($path, $cachefile, $concrete_deps, $pkg.uuid) teardown=slowGC(); append!(df, DataFrame(cat="compilation", testname="create_expr_cache", res=(median(t).time / 1e6))); next!(prog)
    t = @benchmark output_ji("module Foo bar(n)=sum(map(x->rand(),n)) end"); append!(df, DataFrame(cat="compilation", testname="output-ji", res=(median(t).time / 1e6))); next!(prog)
    
    finish!(prog)

    @info "Printing of results may be truncated. To view the full results use `show(res, allrows=true, allcols=true)`"
    return df
end
## CPU
function writevideo(imgstack; delete::Bool=false, path = joinpath(@__DIR__, "testvideo.mp4"))
    VideoIO.encodevideo(path, imgstack, silent=true)
    delete && rm(path)
    return path
end
## DiskIO
function tempwrite(x; delete::Bool=false, path = joinpath(@__DIR__, "testwrite.dat"))
    open(path, "w") do io
        write(io, x)
    end
    delete && rm(path)
    return path
end
function tempread(path)
    x = open(path) do io
        read(io)
    end
    return x
end
## Julia Loading
function runjulia(e)
    juliabin = joinpath(Sys.BINDIR, Base.julia_exename())
    run(`$(joinpath(Sys.BINDIR, Base.julia_exename())) --project=$(dirname(@__DIR__)) --startup-file=no -e "$e"`)
end

function output_ji(e)
    tempout, io = mktemp()
    run(`$(Base.julia_cmd()) -O0 
        --output-ji $tempout --output-incremental=yes 
        --startup-file=no --history-file=no --warn-overwrite=yes 
        --eval "$e"`)
end

## Compilation tests

"""
    compilecache_init(pkg)

A stripped out version of `Base.compilecache(pkg)`` to prepare inputs for `Base.create_expr_cache` benchmark
"""
function compilecache_init(pkg)
    path = Base.locate_package(pkg)
    path === nothing && throw(ArgumentError("$pkg not found during precompilation"))
    # decide where to put the resulting cache file
    cachefile = Base.compilecache_path(pkg)
    # prune the directory with cache files
    if pkg.uuid !== nothing
        cachepath = dirname(cachefile)
        entrypath, entryfile = Base.cache_file_entry(pkg)
        cachefiles = filter!(x -> startswith(x, entryfile * "_"), readdir(cachepath))
        if length(cachefiles) >= Base.MAX_NUM_PRECOMPILE_FILES
            idx = findmin(mtime.(joinpath.(cachepath, cachefiles)))[2]
            rm(joinpath(cachepath, cachefiles[idx]))
        end
    end
    # build up the list of modules that we want the precompile process to preserve
    concrete_deps = copy(Base._concrete_dependencies)
    for (key, mod) in Base.loaded_modules
        if !(mod === Main || mod === Core || mod === Base)
            push!(concrete_deps, key => Base.module_build_id(mod))
        end
    end
    return path, cachefile, concrete_deps
end

function slowGC(t=0.1)
    GC.gc()
    sleep(t)
end

end #module
