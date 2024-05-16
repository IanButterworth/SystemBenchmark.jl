using Test
using SystemBenchmark

@testset "SystemBenchmark" begin
    res = runbenchmark();
    path = joinpath(dirname(@__DIR__), "results.txt")
    savebenchmark(path, res)
    res2 = readbenchmark(path);
    comp = comparetoref(res);
    show(comp, allrows=true, allcols=true)

    crowd = getsubmittedbenchmarks()
    println("") #tidy test printing
end