using Test
using SystemBenchmark

using InteractiveUtils; versioninfo()

@testset "SystemBenchmark" begin
    res = runbenchmark();
    path, io = mktemp()
    savebenchmark(path, res)
    res2 = readbenchmark(path);
    comp = comparetoref(res);
    show(comp, allrows=true, allcols=true)
    
    crowd = getsubmittedbenchmarks()
    println("") #tidy test printing
end