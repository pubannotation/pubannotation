class DocGenerationFromMediaJob < ApplicationJob
  include UseJobRecordConcern

  queue_as :general

  def perform(project, medium, user, attributes)
    task = MediaTranscriptionTask.create!(medium:, job: @job)

    media_transcript = task.process { MediaTextGenerationService.new(medium).call }
    media_transcript.update!(media_transcription_task: task)

    return if media_transcript.text.blank?

    MediaDocCreationService.call(project, medium, user, attributes, media_transcript)
  end

  def job_name
    'Generate doc text from media'
  end
end
