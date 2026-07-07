class Media::JobsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_media_access!
  before_action :set_job

  rescue_from ActiveRecord::RecordNotFound do
    redirect_to jobs_media_path, notice: 'Could not find the job.'
  end

  def show
  end

  private

  def set_job
    @job = current_user.jobs.find(params[:id])
  end

  def authorize_media_access!
    unless current_user&.can_access_media?
      render_status_error(:forbidden)
    end
  end
end
