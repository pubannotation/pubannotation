namespace :import_annotation do
  desc "Import JSON files"
  task from_json: :environment do

    # Get first project
    project = Project.first

    # parse file as json from file path
    annotation = JSON.parse File.read(ARGV[0]), symbolize_names: true
    annotation_list = [annotation] unless annotation.is_a? Array

    # create document if not exists
    annotation_list.each do |annotation|
      sourcedb = annotation[:sourcedb]
      sourceid = annotation[:sourceid]

      if project.docs.where(sourcedb: sourcedb, sourceid: sourceid).count == 0
        project.docs.create!(sourcedb: sourcedb, sourceid: sourceid, body: annotation[:text])
      end
    end

    # import annotations
    InstantiateAndSaveAnnotationsCollection.call project, annotation_list
  end
end
