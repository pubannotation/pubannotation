require 'benchmark'

count = 3
annotations_collection = JSON.parse File.read(ARGV[0])
annotations_collection.each { _1.deep_symbolize_keys! }
project = Project.find_by(id: 1)

Benchmark.bm do
  _1.report("#{count}") do
    count.times do
      InstantiateAndSaveAnnotationsCollection.call project, annotations_collection
    end
  end
end
