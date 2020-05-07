# SystemBenchmark.jl
 Julia package for benchmarking a system. Contributions very welcome.

Run benchmark
```
pkg> add https://github.com/ianshmean/SystemBenchmark.jl
julia> using SystemBenchmark
Julia> res = sysbenchmark()
13×3 DataFrames.DataFrame
│ Row │ cat     │ testname        │ ms          │
│     │ String  │ String          │ Float64     │
├─────┼─────────┼─────────────────┼─────────────┤
│ 1   │ cpu     │ FloatMul        │ 1.61e-6     │
│ 2   │ cpu     │ FloatSin        │ 5.681e-6    │
│ 3   │ cpu     │ VecMulBroad     │ 4.72799e-5  │
│ 4   │ cpu     │ CPUMatMul       │ 0.000379541 │
│ 5   │ cpu     │ MatMulBroad     │ 0.000165929 │
│ 6   │ cpu     │ 3DMulBroad      │ 0.00184215  │
│ 7   │ cpu     │ FFMPEGH264Write │ 230.533     │
│ 8   │ mem     │ DeepCopy        │ 0.000207828 │
│ 9   │ diskio  │ TempdirWrite    │ 0.196437    │
│ 10  │ diskio  │ TempdirRead     │ 0.0691485   │
│ 11  │ loading │ JuliaLoad       │ 282.547     │
│ 12  │ loading │ UsingCSV        │ 1772.47     │
│ 13  │ loading │ UsingVideoIO    │ 4002.58     │
```

Compare benchmark to the default reference (a 2019 MSI Linux Laptop)
```
julia> comparison_df = compareToRef()
```
or
```
julia> comparison_df = compareToRef(sysbenchmark())
Reference system ----------------------
Julia Version 1.4.1
Commit 381693d3df* (2020-04-14 17:20 UTC)
Platform Info:
  OS: Linux (x86_64-pc-linux-gnu)
  CPU: Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz
  WORD_SIZE: 64
  LIBM: libopenlibm
  LLVM: libLLVM-8.0.1 (ORCJIT, skylake)
  GPU (used by CuArrays): GeForce GTX 1650 with Max-Q Design

Test system ---------------------------
Julia Version 1.4.1
Commit 381693d3df* (2020-04-14 17:20 UTC)
Platform Info:
  OS: macOS (x86_64-apple-darwin18.7.0)
  CPU: Intel(R) Core(TM) i7-8850H CPU @ 2.60GHz
  WORD_SIZE: 64
  LIBM: libopenlibm
  LLVM: libLLVM-8.0.1 (ORCJIT, skylake)
Environment:
  JULIA_EDITOR = "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  JULIA_NUM_THREADS = 6


12×5 DataFrame
│ Row │ cat         │ testname        │ ref_ms      │ test_ms     │ factor  │
│     │ String      │ String          │ Float64     │ Float64     │ Float64 │
├─────┼─────────────┼─────────────────┼─────────────┼─────────────┼─────────┤
│ 1   │ cpu         │ FloatMul        │ 1.134e-6    │ 1.715e-6    │ 1.51235 │
│ 2   │ cpu         │ FloatSin        │ 4.051e-6    │ 4.951e-6    │ 1.22217 │
│ 3   │ cpu         │ VecMulBroad     │ 2.99025e-5  │ 3.92925e-5  │ 1.31402 │
│ 4   │ cpu         │ CPUMatMul       │ 0.018874    │ 0.037066    │ 1.96387 │
│ 5   │ cpu         │ MatMulBroad     │ 0.00413388  │ 0.0192804   │ 4.664   │
│ 6   │ cpu         │ 3DMulBroad      │ 0.0010365   │ 0.0016829   │ 1.62364 │
│ 7   │ cpu         │ FFMPEGH264Write │ 105.757     │ 230.524     │ 2.17976 │
│ 8   │ mem         │ DeepCopy        │ 0.000177074 │ 0.000193347 │ 1.0919  │
│ 9   │ diskio      │ TempdirWrite    │ 0.024308    │ 0.18231     │ 7.50002 │
│ 10  │ diskio      │ TempdirRead     │ 0.0049865   │ 0.068471    │ 13.7313 │
│ 11  │ loading     │ JuliaLoad       │ 91.921      │ 218.228     │ 2.37409 │
│ 12  │ compilation │ compilecache    │ 118.46      │ 111.396     │ 0.94037 │

```

Save to disk
```
julia> writeBenchmar("/path/to/file.txt",res)
```

Compare two benchmarks
```
compare(ref::DataFrame, res::DataFrame)
```
