class DocGenerationFromMediaJob < ApplicationJob
  include UseJobRecordConcern

  queue_as :general

  def perform(project, medium, user, attributes)
    service = DocGenerationFromMedia.new(project:, medium:, user:, attributes:)
    task = MediaTranscriptionTask.create!(medium:, job: @job) if medium.transcribable?

    task&.processing!
    body = service.generate_transcript
    task&.succeeded!

    service.save_doc(body)
  rescue StandardError
    task.failed! if task && !task.succeeded?
    raise
  end

  def job_name
    'Generate doc text from media'
  end
end
