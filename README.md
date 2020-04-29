# SystemBenchmark.jl
 Julia package for benchmarking a system

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
│ 4   │ cpu     │ MatMul          │ 0.000379541 │
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
Save to disk
```
julia> using CSV
julia> CSV.write("filename.csv", res)
```

Compare two benchmarks
```
compare(ref::DataFrame, res::DataFrame)
```

Compare benchmark to the default reference (currently a 2018 i7 Macbook pro)
```
julia> compareToRef(sysbenchmark())
13×5 DataFrames.DataFrame
│ Row │ cat     │ testname        │ ref_ms      │ res_ms      │ factor   │
│     │ String  │ String          │ Float64     │ Float64     │ Float64  │
├─────┼─────────┼─────────────────┼─────────────┼─────────────┼──────────┤
│ 1   │ cpu     │ FloatMul        │ 1.61e-6     │ 6.08e-7     │ 0.37764  │
│ 2   │ cpu     │ FloatSin        │ 5.681e-6    │ 8.68342e-6  │ 1.5285   │
│ 3   │ cpu     │ VecMulBroad     │ 4.72799e-5  │ 5.15783e-5  │ 1.09091  │
│ 4   │ cpu     │ MatMul          │ 0.000379541 │ 0.00091201  │ 2.40293  │
│ 5   │ cpu     │ MatMulBroad     │ 0.000165929 │ 0.000199591 │ 1.20287  │
│ 6   │ cpu     │ 3DMulBroad      │ 0.00184215  │ 0.0018017   │ 0.978042 │
│ 7   │ cpu     │ FFMPEGH264Write │ 230.533     │ 616.325     │ 2.67348  │
│ 8   │ mem     │ DeepCopy        │ 0.000207828 │ 0.000339916 │ 1.63556  │
│ 9   │ diskio  │ TempdirWrite    │ 0.196437    │ 0.070913    │ 0.360997 │
│ 10  │ diskio  │ TempdirRead     │ 0.0691485   │ 0.0176      │ 0.254525 │
│ 11  │ loading │ JuliaLoad       │ 282.547     │ 246.116     │ 0.871063 │
│ 12  │ loading │ UsingCSV        │ 1772.47     │ 3065.72     │ 1.72963  │
│ 13  │ loading │ UsingVideoIO    │ 4002.58     │ 15329.0     │ 3.82978  │
```
