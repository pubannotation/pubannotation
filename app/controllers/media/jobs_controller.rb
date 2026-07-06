class Media::JobsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_job

  rescue_from ActiveRecord::RecordNotFound do
    redirect_to jobs_media_path, notice: 'Could not find the job.'
  end

  def show
    @messages_grid = initialize_grid(@job.messages,
      order: :created_at,
      order_direction: :desc,
      per_page: 10
    )
  end

  def destroy
    @job.destroy_unless_running
    redirect_to jobs_media_path
  end

  private

  def set_job
    @job = current_user.jobs.find(params[:id])
  end
end
