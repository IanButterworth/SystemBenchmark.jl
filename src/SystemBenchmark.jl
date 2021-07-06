module SystemBenchmark
using BenchmarkTools
using CUDA
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
    HAS_GPU[] = CUDA.functional()
end

function getinfofield(info::String, field::String)::String
    value = split(info, field)[2]
    return string(strip(split(value,"\n")[1]))
end

function getsysteminfo()
    buf = PipeBuffer()
    InteractiveUtils.versioninfo(buf, verbose=false)
    systeminfo = read(buf, String)

    df = DataFrame(cat=String[], testname=String[], units=String[], res=Any[])
    push!(df, ["info","SysBenchVer","",string(pkgversion())])
    push!(df, ["info","JuliaVer","",getinfofield(systeminfo, "Julia Version")])
    push!(df, ["info","OS","",getinfofield(systeminfo, "OS:")])
    push!(df, ["info","CPU","",getinfofield(systeminfo, "CPU:")])
    push!(df, ["info","WORD_SIZE","",getinfofield(systeminfo, "WORD_SIZE:")])
    push!(df, ["info","LIBM","",getinfofield(systeminfo, "LIBM:")])
    push!(df, ["info","LLVM","",getinfofield(systeminfo, "LLVM:")])
    if HAS_GPU[]
        push!(df, ["info","GPU","",CUDA.name(CUDA.device())])
    else
        push!(df, ["info","GPU","",missing])
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
	df = DataFrame(cat=String[], testname=String[], units=Union{String,Missing}[], ref_res=Any[], test_res=Any[], factor=Any[])
	!("units" in names(ref)) && (ref.units = fill(missing,size(ref,1)))
	!("units" in names(test)) && (test.units = fill(missing,size(ref,1)))
    for testname in unique(test.testname)
		testrow = test[test.testname .== testname, :]
		!in(testname, unique(ref.testname)) && continue #test missing from reference benchmark
        refrow = ref[ref.testname .== testname, :]
        if testrow.cat[1] == "info"
            if ismissing(refrow.res[1] != testrow.res[1]) || (refrow.res[1] != testrow.res[1])
                factor = "Not Equal"
            else
                factor = "Equal"
            end
            push!(df, Dict(:cat=>testrow.cat[1],
                :testname=>testname,
				:units=>testrow.units[1],
                :ref_res=>refrow.res[1],
                :test_res=>testrow.res[1],
                :factor=>factor
                ))
        else
            testres = typeof(testrow.res[1]) == String ? parse(Float64,testrow.res[1]) : testrow.res[1]
            refres = typeof(refrow.res[1]) == String ? parse(Float64,refrow.res[1]) : refrow.res[1]
            push!(df, Dict(:cat=>testrow.cat[1],
                :testname=>testname,
				:units=>testrow.units[1],
                :ref_res=>refrow.res[1],
                :test_res=>testrow.res[1],
                :factor=>testres / refres
                ))
        end
	end
	return df
end

comparetoref(;slowgcsleep=1.0) = comparetoref(runbenchmark(printsysinfo = false, slowgcsleep=slowgcsleep))

function comparetoref(test::DataFrame; refname="ref.txt")
    ref = readbenchmark(joinpath(dirname(@__DIR__), "ref", refname))
    return compare(ref, test)
end

function diskio(;num_zeros = 3:5, digits=1:9)
	for zeros in num_zeros
		for dig in digits
			bytes = parse(Int,"$(dig)$(repeat("0",zeros))")
			path = tempwrite(rand(UInt8,bytes), delete=false)
			t = @benchmark tempread($path);
			time_s = minimum(t).time / 1e9
	        MiB_s = (bytes / time_s)  / (1024 * 1024)
			@info "File size: $(round(Int,bytes/1000)) KB. Read speed: $(round(MiB_s,digits=1)) MiB/s"
		end
	end
end

function runbenchmark(;printsysinfo = true, slowgcsleep = 1.0)
    ntests = 18
    if HAS_GPU[]
        ntests += 1
    else
        @info "CUDA.functional() == false. No usable GPU detected"
    end

	#remove extra CI args in julia cmd
	juliacmd = collect(Base.julia_cmd())
	filter!(x->!in(x, ["--check-bounds=yes", "-g1", "--code-coverage=user", "-O3", "-O2", "-O1", "-O0"]), juliacmd)

    df = getsysteminfo() #initialize DataFrame with system info
    prog = ProgressMeter.Progress(ntests)
    prog.desc = "CPU tests"; ProgressMeter.updateProgress!(prog)
    t = @benchmark x * x setup=(x=rand()); append!(df, DataFrame(cat="cpu", testname="FloatMul", units="ms", res=median(t).time / 1e6)); next!(prog)
    t = @benchmark a * b + c setup=(a=rand(); b=rand(); c=rand()); append!(df, DataFrame(cat="cpu", testname="FusedMulAdd", units="ms", res=median(t).time / 1e6)); next!(prog)
    t = @benchmark sin(x) setup=(x=rand()); append!(df, DataFrame(cat="cpu", testname="FloatSin", units="ms", res=median(t).time / 1e6)); next!(prog)
    t = @benchmark x .* x setup=(x=rand(10)); append!(df, DataFrame(cat="cpu", testname="VecMulBroad", units="ms", res=median(t).time / 1e6)); next!(prog)
    t = @benchmark x * x setup=(x=rand(Float32, 100, 100)); append!(df, DataFrame(cat="cpu", testname="CPUMatMul", units="ms", res=median(t).time / 1e6)); next!(prog)
    t = @benchmark x .* x setup=(x=rand(Float32, 100, 100)); append!(df, DataFrame(cat="cpu", testname="MatMulBroad", units="ms", res=median(t).time / 1e6)); next!(prog)
    t = @benchmark x .* x setup=(x=rand(10,10,10)); append!(df, DataFrame(cat="cpu", testname="3DMulBroad", units="ms", res=median(t).time / 1e6)); next!(prog)
    append!(df, DataFrame(cat="cpu", testname="peakflops", units="flops", res=maximum(LinearAlgebra.peakflops() for _ in 1:10))); next!(prog)

    t = @benchmark writevideo(imgstack) setup=(imgstack=map(x->rand(UInt8,100,100), 1:100)); append!(df, DataFrame(cat="cpu", testname="FFMPEGH264Write", units="ms", res=median(t).time / 1e6)); next!(prog)
    rm(joinpath(@__DIR__, "testvideo.mp4"), force=true)

    if HAS_GPU[]
        prog.desc = "GPU tests"; ProgressMeter.updateProgress!(prog)
        x=cu(rand(Float32,100,100))
        t = @benchmark $x * $x; append!(df, DataFrame(cat="gpu", testname="GPUMatMul", units="ms", res=median(t).time / 1e6)); next!(prog)
    end

    prog.desc = "Memory tests"; ProgressMeter.updateProgress!(prog)
    t = @benchmark deepcopy(x) setup=(x=rand(UInt8,1000)); append!(df, DataFrame(cat="mem", testname="DeepCopy", units="ms", res=median(t).time / 1e6)); next!(prog)
	bandwidths = membandwidthbenchmark(bytes_steps = [10_000, 100_000, 1_000_000, 10_000_000, 100_000_000])
	append!(df, DataFrame(cat="mem", testname="Bandwidth10kB", units="MiB/s", res=bandwidths[1]));
	append!(df, DataFrame(cat="mem", testname="Bandwidth100kB", units="MiB/s", res=bandwidths[2]));
	append!(df, DataFrame(cat="mem", testname="Bandwidth1MB", units="MiB/s", res=bandwidths[3]));
	append!(df, DataFrame(cat="mem", testname="Bandwidth10MB", units="MiB/s", res=bandwidths[4]));
	append!(df, DataFrame(cat="mem", testname="Bandwidth100MB", units="MiB/s", res=bandwidths[5]));
	next!(prog)

    prog.desc = "Disk IO tests"; ProgressMeter.updateProgress!(prog)
    t = @benchmark tempwrite(x) setup=(x=rand(UInt8,1000)); append!(df, DataFrame(cat="diskio", testname="DiskWrite1KB", units="ms", res=median(t).time / 1e6)); next!(prog)
    t = @benchmark tempwrite(x) setup=(x=rand(UInt8,1000000)); append!(df, DataFrame(cat="diskio", testname="DiskWrite1MB", units="ms", res=median(t).time / 1e6)); next!(prog)
    t = @benchmark tempread(path) setup=(path = tempwrite(rand(UInt8,1000), delete=false)); append!(df, DataFrame(cat="diskio", testname="DiskRead1KB", units="ms", res=median(t).time / 1e6)); next!(prog)
    rm(joinpath(@__DIR__, "testwrite.dat"), force=true)
    t = @benchmark tempread(path) setup=(path = tempwrite(rand(UInt8,1000000), delete=false)); append!(df, DataFrame(cat="diskio", testname="DiskRead1MB", units="ms", res=median(t).time / 1e6)); next!(prog)
    rm(joinpath(@__DIR__, "testwrite.dat"), force=true)

    prog.desc = "Julia loading tests"; ProgressMeter.updateProgress!(prog)
    t = @benchmark runjulia("1+1"); append!(df, DataFrame(cat="loading", testname="JuliaLoad", units="ms", res=median(t).time / 1e6)); next!(prog)
    juliatime = median(t).time / 1e6

    prog.desc = "Compilation tests"; ProgressMeter.updateProgress!(prog)
	tmpdir = mktempdir()
	insert!(LOAD_PATH, 1, @__DIR__); insert!(DEPOT_PATH, 1, tmpdir)
    Logging.with_logger(NullLogger()) do
        pkg = Base.PkgId("ExampleModule")
        t = @benchmark Base.compilecache($pkg) teardown=rm(joinpath($tmpdir,"compiled"), recursive=true, force=true); append!(df, DataFrame(cat="compilation", testname="compilecache", units="ms", res=(median(t).time / 1e6))); next!(prog)
    end
    deleteat!(LOAD_PATH,1); deleteat!(DEPOT_PATH,1)
    finish!(prog)

    @info "Printing of results may be truncated. To view the full results use `show(res, allrows=true, allcols=true)`"
    return df
end

## CPU
function writevideo(imgstack; delete::Bool=false, path = joinpath(@__DIR__, "testvideo.mp4"))
    VideoIO.save(path, imgstack)
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

## Memory bandwidth

"""
    membandwidthbenchmark() => bandwidths_MiB_s

Run memory bandwidth benchmark, testing deepcopying on arrays of size
`bytes_steps` which defaults to orders of magnitude from 10kB to 100 MB
"""
function membandwidthbenchmark(;bytes_steps = [10_000, 100_000, 1_000_000, 10_000_000, 100_000_000])
    bandwidths_MiB_s = Float64[]
    for bytes in bytes_steps
        t = @benchmark copy!(y, x) setup=(x=rand(UInt8,$bytes);y=rand(UInt8,$bytes))
        time_s = minimum(t).time / 1e9
        push!(bandwidths_MiB_s, (bytes / time_s)  / (1024 * 1024))
        @debug "$(bytes/1000000) MB test: $(last(bandwidths_MiB_s)) MiB/s"
    end
    @debug "Mean bandwidth: $(round(mean(bandwidths_MiB_s),digits=2)) MiB/s"
    @debug "Max bandwidth: $(round(maximum(bandwidths_MiB_s),digits=2)) MiB/s"
    return bandwidths_MiB_s
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
    cachefile = Base.compilecache_path(pkg, UInt64(0)) # fake prefs hash
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
function slowGC(t=1.0)
    GC.gc()
    sleep(t)
end
function runjuliabasic()
    run(`$(Base.julia_cmd()) -O0 --startup-file=no --history-file=no --eval="1"`)
end

const EXAMPLEMOD = joinpath(@__DIR__, "ExampleModule.jl")
function output_ji(juliacmd, tempout)
	run(`$juliacmd -O0 --output-ji $tempout --output-incremental=yes --startup-file=no --history-file=no --warn-overwrite=yes $EXAMPLEMOD`)
end

end #module
