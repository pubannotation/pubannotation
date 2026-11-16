class DocGenerationFromMediaJob < ApplicationJob
  include UseJobRecordConcern

  JOB_NAME = 'Generate doc text from media'.freeze

  queue_as :general

  def perform(project, medium, user, attributes, caption_model)
    task = MediaTranscriptionTask.create!(medium:, job: @job)

    media_transcript = task.process { MediaTextGenerationService.new(medium, caption_model).call }

    if media_transcript.text.present?
      MediaDocCreationService.call(project, medium, user, attributes, media_transcript)
      broadcast_update(:reload_media_docs, 'media_documents')
    end
  end

  def job_name
    JOB_NAME
  end

  private

  def broadcast_update(action, target, job = @job)
    return unless job

    Turbo::StreamsChannel.broadcast_action_to(
      job.organization, :doc_generations,
      action: action, target: target
    )
  rescue StandardError => e
    Rails.logger.error("Could not broadcast document list update: #{e.class}: #{e.message}")
  end
end
