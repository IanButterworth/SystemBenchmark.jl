using Test
using SystemBenchmark

@testset "SystemBenchmark" begin
    res = sysbenchmark();
    path, io = mktemp()
    saveBenchmark(path, res)
    res2 = readBenchmark(path);
    comp = compareToRef(res);
    show(comp, allrows=true)
    println("") #tidy test printing
end