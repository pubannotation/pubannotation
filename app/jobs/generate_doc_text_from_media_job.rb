class GenerateDocTextFromMediaJob < ApplicationJob
  include UseJobRecordConcern

  queue_as :general

  def perform(project, user, hdoc, medium)
    medium.file.open do |f|
      hdoc = hdoc.except('text').merge('body' => ImageCaptionService.new(f.path).call)
    end

    hdoc = Doc.hdoc_normalize!(hdoc.with_indifferent_access, user, user.root?)
    doc  = Doc.store_hdoc!(hdoc)
    project.add_doc!(doc)
  end

  def job_name
    'Generate doc text from media'
  end
end
