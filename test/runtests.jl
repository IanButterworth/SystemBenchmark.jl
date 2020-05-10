using Test
using SystemBenchmark

@testset "SystemBenchmark" begin
    res = runbenchmark();
    path, io = mktemp()
    savebenchmark(path, res)
    res2 = readbenchmark(path);
    comp = comparetoref(res);
    show(comp, allrows=true, allcols=true)
    println("") #tidy test printing
end