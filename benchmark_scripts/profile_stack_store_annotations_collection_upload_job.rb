project = Project.find_by(id: 1)
filepath = './benchmark_scripts/PMC-7646410.json'
options = { mode: "replace" }

StackProf.run(out: 'tmp/stackprof.dump', raw: true) do
  begin
    StoreAnnotationsCollectionUploadJob.perform_now project, filepath, options
  rescue ArgumentError
    puts "ArgumentError"
  end
end
