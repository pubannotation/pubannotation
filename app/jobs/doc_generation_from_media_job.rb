class DocGenerationFromMediaJob < ApplicationJob
  include UseJobRecordConcern

  queue_as :general

  def perform(project, medium, user, attributes)
    service = DocGenerationFromMedia.new(project:, medium:, user:, attributes:)

    body = if medium.transcribable?
      MediaTranscriptionTask.create!(medium:, job: @job).process { service.generate_transcript }
    else
      service.generate_transcript
    end

    service.save_doc(body)
  end

  def job_name
    'Generate doc text from media'
  end
end
