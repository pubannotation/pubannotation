# Benchmark scripts for Uploading annotations

To tuning uploading annotations, we need to benchmark the uploading speed.
This folder contains the scripts for benchmarking the inserting speed of uploaded annotations to DBs.
These scripts benchmark the InstantiateAndSaveAnnotationsCollection.call method.

Test data is contained in the PMC-7646410.json.

## Benchmarking total speed

This script is benchmarking the total speed of inserting annotations.
It is using the PMC-7646410.json file.

```bash
►bin/rails runner ./bench_instantiate_and_save_annotat
ions_collection.rb ./PMC-7646410.json
```

## Benchmarking speed for each process

This script is benchmarking the speed for each process of inserting annotations. 
It is using the PMC-7646410.json file.

To run this script, you need to install the StackProf gem.

```bash
bundle add stackprof
```

and run:

```bash
bin/rails runner profile_stack_instantiate_and_save_a
nnotations_collection.rb
stackprof --d3-flamegraph tmp/stackprof.dump > frameg
raph.html
```

Open the framegraph.html to see the flame graph.

If you want uninstall the StacProf gem, run:

```bash
bundle remove stackprof
```
