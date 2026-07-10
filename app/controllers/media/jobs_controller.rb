class Media::JobsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_media_access!
  before_action :set_job, only: [:show]

  rescue_from ActiveRecord::RecordNotFound do
    redirect_to media_jobs_path, notice: 'Could not find the job.'
  end

  def index
    @jobs = current_user.jobs.order(created_at: :desc)
    @job_message_counts = message_counts_for(@jobs)
    @reload_necessary = @jobs.any?(&:unfinished?)
  end

  def show
  end

  def latest_jobs_table
    @jobs = current_user.jobs.order(created_at: :desc)
    @job_message_counts = message_counts_for(@jobs)
    @reload_necessary = @jobs.any?(&:unfinished?)
    render partial: 'jobs_table', locals: { jobs: @jobs, message_counts: @job_message_counts, reload_necessary: @reload_necessary }
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

  def message_counts_for(jobs)
    Message.where(job_id: jobs.select(:id)).group(:job_id).count
  end
end
