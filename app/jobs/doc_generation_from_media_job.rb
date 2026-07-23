class DocGenerationFromMediaJob < ApplicationJob
  include UseJobRecordConcern

  queue_as :general

  def perform(project, medium, user, attributes)
    DocGenerationFromMedia.new(project: project, medium: medium, user: user, attributes: attributes).call
  end

  def job_name
    'Generate doc text from media'
  end
end
