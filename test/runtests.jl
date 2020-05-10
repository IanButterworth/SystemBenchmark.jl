using Test
using SystemBenchmark

@testset "SystemBenchmark" begin
    res = runbenchmark();
    path, io = mktemp()
    saveBenchmark(path, res)
    res2 = readBenchmark(path);
    comp = compareToRef(res);
    show(comp, allrows=true, allcols=true)
    println("") #tidy test printing
end