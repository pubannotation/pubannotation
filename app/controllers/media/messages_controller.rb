class Media::MessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_media_access!
  before_action :set_message

  rescue_from ActiveRecord::RecordNotFound do
    redirect_to media_jobs_path, notice: 'Could not find the message.'
  end

  def show
  end

  private

  def set_message
    @job = current_user.jobs.find(params[:job_id])
    @message = @job.messages.find(params[:id])
  end

  def authorize_media_access!
    unless current_user&.can_access_media?
      render_status_error(:forbidden)
    end
  end
end
