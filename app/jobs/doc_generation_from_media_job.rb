class DocGenerationFromMediaJob < ApplicationJob
  include UseJobRecordConcern

  JOB_NAME = 'Generate doc text from media'.freeze

  queue_as :general

  def perform(project, medium, user, attributes, caption_model)
    task = MediaTranscriptionTask.create!(medium:, job: @job)

    media_transcript = task.process { MediaTextGenerationService.new(medium, caption_model).call }

    if media_transcript.text.present?
      MediaDocCreationService.call(project, medium, user, attributes, media_transcript)
    end
  end

  def job_name
    JOB_NAME
  end

  def before_perform(active_job)
    super
    broadcast_status
  end

  def after_perform
    super
    broadcast_status
  end

  def handle_standard_error(exception)
    super
    broadcast_status
  end

  private

  def broadcast_status
    return unless @job

    Turbo::StreamsChannel.broadcast_action_to(
      @job.organization, :doc_generations,
      action: :reload_media_generation, target: 'doc_generation_status'
    )
  rescue StandardError => e
    Rails.logger.error("Could not broadcast document generation status: #{e.class}: #{e.message}")
  end
end
