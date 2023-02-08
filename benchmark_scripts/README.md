# Benchmark scripts for Uploading annotations

To tuning uploading annotations, we need to benchmark the uploading speed.
This folder contains the scripts for benchmarking the inserting speed of uploaded annotations to DBs.
These scripts benchmark the InstantiateAndSaveAnnotationsCollection.call method.

Test data is contained in the PMC-7646410.json.

## Benchmarking total speed

This script is benchmarking the total speed of inserting annotations.
It is using the PMC-7646410.json file.

```bash
bin/rails runner ./bench_instantiate_and_save_annotat
ions_collection.rb ./PMC-7646410.json
```

## Benchmarking speed for each process

This script is benchmarking the speed for each process of inserting annotations. 
It is using the PMC-7646410.json file.

### InstantiateAndSaveAnnotationsCollection


```bash
bin/rails runner profile_stack_instantiate_and_save_annotations_collection.rb
```

### StoreAnnotationsCollectionUploadJob


```bash
bin/rails runner profile_stack_store_annotations_collection_upload_job.rb
```


### View profiles in browesers

```bash
stackprof --d3-flamegraph tmp/stackprof.dump > framegraph.html
```

Open the framegraph.html to see the flame graph.
