class DocGenerationFromMediaJob < ApplicationJob
  include UseJobRecordConcern

  queue_as :general

  def perform(project, medium, user, attributes)
    service = DocGenerationFromMedia.new(project:, medium:, user:, attributes:)
    task = MediaTranscriptionTask.create!(medium:, job: @job)
    body, segments = task.process { service.generate_transcript }
    return if task.no_speech?

    service.save_doc(body, segments, media_transcription_task: task)
  end

  def job_name
    'Generate doc text from media'
  end
end
