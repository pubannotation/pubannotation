file = './benchmark_scripts/PMC-7646410.json'
annotations_collection = JSON.parse File.read(file)
annotations_collection.each { _1.deep_symbolize_keys! }
project = Project.find_by(id: 1)

StackProf.run(out: 'tmp/stackprof.dump', raw: true) do
  InstantiateAndSaveAnnotationsCollection.call project, annotations_collection
end
