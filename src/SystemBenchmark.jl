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

const HAS_GPU = Ref{Bool}(false)

function __init__()
    HAS_GPU[] = CuArrays.functional()
end

function getSystemInfo()
    buf = PipeBuffer()
    InteractiveUtils.versioninfo(buf, verbose=false)
    systeminfo = read(buf, String)
    HAS_GPU[] && (systeminfo *= string("  GPU: $(CuArrays.CUDAdrv.name(CuArrays.CUDAdrv.device()))"))
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

function compare(ref_sysinfo::String, ref::DataFrame, test_sysinfo::String, test::DataFrame)
    println("Reference system ----------------------")
    println(ref_sysinfo)
    println("Test system ---------------------------")
    println(test_sysinfo)
    println("")
    return compare(ref::DataFrame, test::DataFrame)
end

compareToRef() = compareToRef(sysbenchmark(printsysinfo = false))

function compareToRef(test::DataFrame; refname="1-linux-i7-2.6GHz-GTX1650.txt")
    test_sysinfo = getSystemInfo()
    ref_sysinfo, ref = readBenchmark(joinpath(dirname(@__DIR__), "ref", refname))
    return compare(string(ref_sysinfo), ref, test_sysinfo, test)
end

function sysbenchmark(;printsysinfo = true)
    ntests = 12
    systeminfo = getSystemInfo()

    if HAS_GPU[]
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
    t = @benchmark x * x setup=(x=rand(Float32, 100, 100)); append!(df, DataFrame(cat="cpu", testname="CPUMatMul", ms=median(t).time / 1e6)); next!(prog)
    t = @benchmark x .* x setup=(x=rand(Float32, 100, 100)); append!(df, DataFrame(cat="cpu", testname="MatMulBroad", ms=median(t).time / 1e6)); next!(prog)
    t = @benchmark x .* x setup=(x=rand(10,10,10)); append!(df, DataFrame(cat="cpu", testname="3DMulBroad", ms=median(t).time / 1e6)); next!(prog)
    t = @benchmark writevideo(imgstack) setup=(imgstack=map(x->rand(UInt8,100,100), 1:100)); append!(df, DataFrame(cat="cpu", testname="FFMPEGH264Write", ms=median(t).time / 1e6)); next!(prog)
    t = @benchmark a * b + c setup=(a=rand(),b=rand(),c=rand()); append!(df, DataFrame(cat="cpu", testname="FusedMulAdd", res=median(t).time / 1e6)); next!(prog)
    append!(df, DataFrame(cat="cpu", testname="peakflops", res=LinearAlgebra.peakflops())); next!(prog)
    isfile(joinpath(@__DIR__, "testvideo.mp4")) && rm(joinpath(@__DIR__, "testvideo.mp4"))

    if HAS_GPU[]
        prog.desc = "GPU tests"
        x=cu(rand(Float32,100,100))
        t = @benchmark $x * $x; append!(df, DataFrame(cat="gpu", testname="GPUMatMul", ms=median(t).time / 1e6)); next!(prog)
    end

    prog.desc = "Memory tests"
    t = @benchmark deepcopy(x) setup=(x=rand(UInt8,1000)); append!(df, DataFrame(cat="mem", testname="DeepCopy", ms=median(t).time / 1e6)); next!(prog)
    
    prog.desc = "Disk IO tests"
    t = @benchmark tempwrite(x) setup=(x=rand(UInt8,1000)); append!(df, DataFrame(cat="diskio", testname="DiskWrite1KB", ms=median(t).time / 1e6)); next!(prog)
    t = @benchmark tempwrite(x) setup=(x=rand(UInt8,1000000)); append!(df, DataFrame(cat="diskio", testname="DiskWrite1MB", ms=median(t).time / 1e6)); next!(prog)
    t = @benchmark tempread(path) setup=(path = tempwrite(rand(UInt8,1000), delete=false)); append!(df, DataFrame(cat="diskio", testname="DiskRead1KB", ms=median(t).time / 1e6)); next!(prog)
    isfile(joinpath(@__DIR__, "testwrite.dat")) && rm(joinpath(@__DIR__, "testwrite.dat"))
    t = @benchmark tempread(path) setup=(path = tempwrite(rand(UInt8,1000000), delete=false)); append!(df, DataFrame(cat="diskio", testname="DiskRead1MB", ms=median(t).time / 1e6)); next!(prog)
    isfile(joinpath(@__DIR__, "testwrite.dat")) && rm(joinpath(@__DIR__, "testwrite.dat"))
    

    prog.desc = "Julia loading tests"
    t = @benchmark runjulia("1+1"); append!(df, DataFrame(cat="loading", testname="JuliaLoad", ms=median(t).time / 1e6)); next!(prog)
    juliatime = median(t).time / 1e6

    prog.desc = "Compilation tests"
    insert!(LOAD_PATH, 1, @__DIR__); insert!(DEPOT_PATH, 1, mktempdir())
    Logging.disable_logging(Logging.Info)
    pkg = Base.PkgId("ExampleModule")
    t = @benchmark Base.compilecache($pkg); append!(df, DataFrame(cat="compilation", testname="compilecache", res=(median(t).time / 1e6))); next!(prog)
    path, cachefile, concrete_deps = compilecache_init(pkg)
    t = @benchmark Base.create_expr_cache($path, $cachefile, $concrete_deps, $pkg.uuid); append!(df, DataFrame(cat="compilation", testname="create_expr_cache", res=(median(t).time / 1e6))); next!(prog)
    
    Logging.disable_logging(Logging.Debug)
    deleteat!(LOAD_PATH,1); deleteat!(DEPOT_PATH,1)

    finish!(prog)
    printsysinfo && println(systeminfo)
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

end #module