using SystemBenchmark
using CSV
using DataFrames
using Plots
using Statistics
gr()

function make_relative!(df)
    for col in 12:size(df,2)
        names(df)[col] in ("CPU_THREADS", "BLAS", "BLAS_threads") && continue
        try
            df[!,col] = df[!,col] ./ df[1,col]
        catch
            @error "Failed to make col $(names(df)[col]) relative"
        end
    end

    df[!,:mean_cpu] = map(x->mean([x.FloatMul,
        # x.FusedMulAdd, # results unreliable before 0.2.1
        x.FloatSin,
        x.VecMulBroad,
        #x.CPUMatMul,
        x.MatMulBroad,
        x[Symbol("3DMulBroad")]]),eachrow(df))

    df[!,:mean_diskio] = map(x->mean([x.DiskWrite1KB,
        x.DiskWrite1MB,
        x.DiskRead1KB,
        x.DiskRead1MB]),eachrow(df))
    return df
end


function plotreport(df, figurepath; scale=2.0)
    platforms = ["Windows", "macOS", "Linux (x86", "Linux (aarch"]
    colors = [:blue,:orange,:green,:purple]

    p1 = plot(dpi=300)
    plot!(0:100,0:100,color=:gray)
    i = 1
    for plat = platforms
        df2 = df[occursin.(plat,df.OS),:]
        scatter!(df2[!,:mean_cpu], df2[!,:compilecache], label=replace(plat,"("=>""), leg=false,ms=4,markerstrokewidth=0,color=colors[i])
        xlabel!("Mean CPU time (relative to ref)")
        ylabel!("compilecache time\n(relative to ref)")
        i += 1
    end
    xlims!(0,7); ylims!(0,7)

    p2 = plot()
    plot!(0:100,0:100,color=:gray,label="parity")
    i = 1
    for plat in platforms
        df2 = df[occursin.(plat,df.OS),:]
        scatter!(df2[!,:mean_cpu],df2[!,:JuliaLoad],label=replace(plat,"("=>""), legend=:best, bg_legend = :transparent, fg_legend = :transparent,ms=4,markerstrokewidth=0,color=colors[i])
        xlabel!("Mean CPU time (relative to ref)")
        ylabel!("Julia startup time\n(relative to ref)")
        i += 1
    end
    xlims!(0,7); ylims!(0,7)

    p3 = plot()
    plot!(0:100,0:100,color=:gray)
    i = 1
    for plat in platforms
        df2 = df[occursin.(plat,df.OS),:]
        scatter!(df2[!,:mean_cpu],df2[!,:mean_diskio],label=replace(plat,"("=>""), fontsize=4,leg=false,ms=4,markerstrokewidth=0,color=colors[i])
        xlabel!("Mean CPU time (relative to ref)")
        ylabel!("Mean disk IO time\n(relative to ref)")
        i += 1
    end
    xlims!(0,7); ylims!(0,45)

    p4 = plot()
    plot!(0:100,0:100,color=:gray)
    i = 1
    for plat in platforms
        df2 = df[occursin.(plat,df.OS),:]
        scatter!(df2[!,Symbol("compilecache")],df2[!,Symbol("FFMPEGH264Write")],label=replace(plat,"("=>""), fontsize=4,leg=false,ms=4,markerstrokewidth=0,color=colors[i])
        xlabel!("compilecache time\n(relative to ref)")
        ylabel!("FFMPEGH264Write time\n(relative to ref)")
        i += 1
    end
    xlims!(0,12); ylims!(0,12)

    plot(p1,p2,p3,p4,dpi=300,size=(400*scale,300*scale))

    savefig(figurepath)
end

function memoryreport(df_in, figurepath; scale=2.0)
    df = deepcopy(df_in)
    platforms = ["Windows", "macOS", "Linux (x86", "Linux (aarch"]
    colors = [:blue,:orange,:green,:purple]

    p1 = plot(dpi=300)
    i = 1
    for plat = platforms
        df2 = df[occursin.(plat,df.OS),:]
        x = df2[!,:mean_cpu]
        y = df2[!,:Bandwidth10kB]
        x = x[.!ismissing.(y)]
        y = y[.!ismissing.(y)]
        scatter!(x, y, label=replace(plat,"("=>""), leg=false,ms=4,markerstrokewidth=0,color=colors[i])
        xlabel!("Mean CPU time")
        ylabel!("Bandwidth10kB")
        i += 1
    end
    #xlims!(0,10); ylims!(0,15)

    p2 = plot()
    i = 1
    for plat in platforms
        df2 = df[occursin.(plat,df.OS),:]
        x = df2[!,:mean_cpu]
        y = df2[!,:Bandwidth100kB]
        x = x[.!ismissing.(y)]
        y = y[.!ismissing.(y)]
        scatter!(x, y, label=replace(plat,"("=>""), legend=:best, bg_legend = :transparent, fg_legend = :transparent,ms=4,markerstrokewidth=0,color=colors[i])
        xlabel!("Mean CPU time")
        ylabel!("Bandwidth100kB")
        i += 1
    end
    #xlims!(0,10); ylims!(0,15)

    # p3 = plot()
    # i = 1
    # for plat in platforms
    #     df2 = df[occursin.(plat,df.OS),:]
    #     x = df2[!,:mean_cpu]
    #     y = df2[!,:Bandwidth1MB]
    #     x = x[.!ismissing.(y)]
    #     y = y[.!ismissing.(y)]
    #     scatter!(x, y, label=replace(plat,"("=>""), leg=false,ms=4,markerstrokewidth=0,color=colors[i])
    #     xlabel!("Mean CPU time")
    #     ylabel!("Bandwidth1MB")
    #     i += 1
    # end

    p3 = plot()
    i = 1
    for plat in platforms
        df2 = df[occursin.(plat,df.OS),:]
        x = df2[!,:mean_cpu]
        y = df2[!,:Bandwidth10MB]
        x = x[.!ismissing.(y)]
        y = y[.!ismissing.(y)]
        scatter!(x, y, label=replace(plat,"("=>""), leg=false,ms=4,markerstrokewidth=0,color=colors[i])
        xlabel!("Mean CPU time")
        ylabel!("Bandwidth10MB")
        i += 1
    end

    p4 = plot()
    i = 1
    for plat in platforms
        df2 = df[occursin.(plat,df.OS),:]
        x = df2[!,:mean_cpu]
        y = df2[!,:DeepCopy]
        x = x[.!ismissing.(y)]
        y = y[.!ismissing.(y)]
        scatter!(x, y, label=replace(plat,"("=>""), leg=false,ms=4,markerstrokewidth=0,color=colors[i])
        xlabel!("Mean CPU time")
        ylabel!("DeepCopy")
        i += 1
    end

    plot(p1,p2,p3,p4,dpi=300,size=(400*scale,300*scale))

    savefig(figurepath)
end

using SystemBenchmark
df = getsubmittedbenchmarks()
make_relative!(df)
savebenchmark(joinpath(@__DIR__,"all.csv"), df)
plotreport(df, joinpath(@__DIR__,"summary_report.png"))
memoryreport(df, joinpath(@__DIR__,"memory_report.png"))

