# SystemBenchmark.jl
 Julia package for benchmarking a system. Not yet released. Contributions very welcome, to help arrive at a stable test set.

Run benchmark
```
pkg> add https://github.com/ianshmean/SystemBenchmark.jl
julia> using SystemBenchmark
julia> res = runbenchmark();
julia> show(res, allrows=true)
25×3 DataFrame
│ Row │ cat         │ testname          │ res                                      │
│     │ String      │ String            │ Any                                      │
├─────┼─────────────┼───────────────────┼──────────────────────────────────────────┤
│ 1   │ info        │ SysBenchVer       │ 0.2.0                                    │
│ 2   │ info        │ JuliaVer          │ 1.4.1                                    │
│ 3   │ info        │ OS                │ macOS (x86_64-apple-darwin18.7.0)        │
│ 4   │ info        │ CPU               │ Intel(R) Core(TM) i7-8850H CPU @ 2.60GHz │
│ 5   │ info        │ WORD_SIZE         │ 64                                       │
│ 6   │ info        │ LIBM              │ libopenlibm                              │
│ 7   │ info        │ LLVM              │ libLLVM-8.0.1 (ORCJIT, skylake)          │
│ 8   │ info        │ GPU               │ missing                                  │
│ 9   │ cpu         │ FloatMul          │ 1.766e-6                                 │
│ 10  │ cpu         │ FusedMulAdd       │ 4.2e-8                                   │
│ 11  │ cpu         │ FloatSin          │ 5.397e-6                                 │
│ 12  │ cpu         │ VecMulBroad       │ 4.66298e-5                               │
│ 13  │ cpu         │ CPUMatMul         │ 0.036044                                 │
│ 14  │ cpu         │ MatMulBroad       │ 0.0190607                                │
│ 15  │ cpu         │ 3DMulBroad        │ 0.00169715                               │
│ 16  │ cpu         │ peakflops         │ 1.98568e11                               │
│ 17  │ cpu         │ FFMPEGH264Write   │ 230.004                                  │
│ 18  │ mem         │ DeepCopy          │ 0.000206386                              │
│ 19  │ diskio      │ DiskWrite1KB      │ 0.142076                                 │
│ 20  │ diskio      │ DiskWrite1MB      │ 0.686615                                 │
│ 21  │ diskio      │ DiskRead1KB       │ 0.0691395                                │
│ 22  │ diskio      │ DiskRead1MB       │ 0.527845                                 │
│ 23  │ loading     │ JuliaLoad         │ 233.506                                  │
│ 24  │ compilation │ compilecache      │ 373.706                                  │
│ 25  │ compilation │ create_expr_cache │ 12.482                                   │
```

Compare benchmark to the default reference (a 2019 MSI Linux i7 Laptop with )
```
julia> comp = compareToRef(res)
```
or to run the benchmark and do the comparison in one move:
```
julia> comp = compareToRef()
[ Info: CuArrays.functional() == false. No usable GPU detected
Compilation tests100%|██████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████| Time: 0:01:58
[ Info: Printing of results may be truncated. To view the full results use `show(res, allrows=true)`
25×5 DataFrames.DataFrame
│ Row │ cat         │ testname          │ ref_res                                  │ test_res                                 │ factor    │
│     │ String      │ String            │ Any                                      │ Any                                      │ Any       │
├─────┼─────────────┼───────────────────┼──────────────────────────────────────────┼──────────────────────────────────────────┼───────────┤
│ 1   │ info        │ SysBenchVer       │ 0.2.0                                    │ 0.2.0                                    │ Equal     │
│ 2   │ info        │ JuliaVer          │ 1.4.1                                    │ 1.4.1                                    │ Equal     │
│ 3   │ info        │ OS                │ Linux (x86_64-pc-linux-gnu)              │ macOS (x86_64-apple-darwin18.7.0)        │ Not equal │
│ 4   │ info        │ CPU               │ Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz │ Intel(R) Core(TM) i7-8850H CPU @ 2.60GHz │ Not equal │
│ 5   │ info        │ WORD_SIZE         │ 64                                       │ 64                                       │ Equal     │
│ 6   │ info        │ LIBM              │ libopenlibm                              │ libopenlibm                              │ Equal     │
│ 7   │ info        │ LLVM              │ libLLVM-8.0.1 (ORCJIT, skylake)          │ libLLVM-8.0.1 (ORCJIT, skylake)          │ Equal     │
│ 8   │ info        │ GPU               │ missing                                  │ missing                                  │ Equal     │
│ 9   │ cpu         │ FloatMul          │ 1.1339999999999999e-6                    │ 1.712e-6                                 │ 1.5097    │
│ 10  │ cpu         │ FusedMulAdd       │ 1.6e-8                                   │ 3.8e-8                                   │ 2.375     │
│ 11  │ cpu         │ FloatSin          │ 3.615e-6                                 │ 5.895e-6                                 │ 1.63071   │
│ 12  │ cpu         │ VecMulBroad       │ 2.9521608040201004e-5                    │ 5.32994e-5                               │ 1.80544   │
│ 13  │ cpu         │ CPUMatMul         │ 0.0287155                                │ 0.0405345                                │ 1.41159   │
│ 14  │ cpu         │ MatMulBroad       │ 0.0045513333333333334                    │ 0.039575                                 │ 8.69525   │
│ 15  │ cpu         │ 3DMulBroad        │ 0.0011464000000000001                    │ 0.00461081                               │ 4.02199   │
│ 16  │ cpu         │ peakflops         │ 1.4181657387608237e11                    │ 2.08713e11                               │ 1.47171   │
│ 17  │ cpu         │ FFMPEGH264Write   │ 137.047713                               │ 247.21                                   │ 1.80383   │
│ 18  │ mem         │ DeepCopy          │ 0.0001815                                │ 0.000220008                              │ 1.21216   │
│ 19  │ diskio      │ DiskWrite1KB      │ 0.0427835                                │ 0.142784                                 │ 3.33736   │
│ 20  │ diskio      │ DiskWrite1MB      │ 0.875754                                 │ 0.794882                                 │ 0.907654  │
│ 21  │ diskio      │ DiskRead1KB       │ 0.0078745                                │ 0.073282                                 │ 9.30624   │
│ 22  │ diskio      │ DiskRead1MB       │ 0.150918                                 │ 0.570236                                 │ 3.77845   │
│ 23  │ loading     │ JuliaLoad         │ 100.8979295                              │ 252.624                                  │ 2.50376   │
│ 24  │ compilation │ compilecache      │ 269.615246                               │ 456.467                                  │ 1.69303   │
│ 25  │ compilation │ create_expr_cache │ 1.148646                                 │ 9.60561                                  │ 8.36255   │

```

Save to disk (includes a system report)
```
writeBenchmark(path::String, res::DataFrame)
```

Compare two benchmarks
```
compare(ref::DataFrame, res::DataFrame)
```

## Submitting Benchmarks

It would be great to collect data across all the platforms being used.
Please consider submitting results in this thread: [SystemBenchmark.jl/issues/8](https://github.com/ianshmean/SystemBenchmark.jl/issues/8)

