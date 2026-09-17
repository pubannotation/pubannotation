class DocGenerationFromMediaJob < ApplicationJob
  include UseJobRecordConcern

  queue_as :general

  def perform(project, medium, user, attributes, caption_model = nil)
    task = MediaTranscriptionTask.create!(medium:, job: @job)

    media_transcript = task.process { MediaTextGenerationService.new(medium, caption_model:).call }

    if media_transcript.text.present?
      MediaDocCreationService.call(project, medium, user, attributes, media_transcript)
    end
  end

  def job_name
    'Generate doc text from media'
  end
end
