using Test
using SystemBenchmark

@testset "SystemBenchmark" begin
    res = runbenchmark();
    path, io = mktemp()
    savebenchmark(path, res)
    res2 = readbenchmark(path);
    comp = comparetoref(res);
    show(comp, allrows=true, allcols=true)

    if haskey(ENV, "CI") && get(ENV, "PERSONAL_ACCESS_TOKEN", "") == ""
        @warn """No PERSONAL_ACCESS_TOKEN ENV var value provided, so the crowdsource analysis tests cannot run in CI.
            This may be because you're PR-ing a fork branch."""
    else
        crowd = getsubmittedbenchmarks()
        println("") #tidy test printing
    end
end