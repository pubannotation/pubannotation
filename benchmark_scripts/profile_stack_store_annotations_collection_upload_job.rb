require 'fileutils'

project = Project.find_by(id: 1)
filepath = './benchmark_scripts/PMC-7646410_2.json'
options = { mode: "replace" }

# prepare tmp directory
FileUtils.mkdir_p 'tmp/uploads'
FileUtils.rm_rf 'tmp/uploads/PMC-7646410'

StackProf.run(out: 'tmp/stackprof.dump', raw: true) do
  begin
    StoreAnnotationsCollectionUploadJob.perform_now project, filepath, options
  rescue StoreAnnotationsCollectionWarnings::Exception
    # ignore logs
  end
end
