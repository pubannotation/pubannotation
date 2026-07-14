class Media::JobsController < ApplicationController
  include MediaAccessAuthorizationConcern

  before_action :authenticate_user!
  before_action :authorize_media_access!
  before_action :set_job, only: [:show]

  rescue_from ActiveRecord::RecordNotFound do
    redirect_to media_jobs_path, notice: 'Could not find the job.'
  end

  def index
    load_jobs
  end

  def show
    @messages_grid = initialize_grid(@job.messages,
      order: :created_at,
      order_direction: :desc,
      per_page: 10
    )
  end

  def latest_jobs_table
    load_jobs
    render partial: 'jobs_table', locals: { jobs: @jobs, message_counts: @job_message_counts, reload_necessary: @reload_necessary }
  end

  private

  def load_jobs
    @jobs = current_user.jobs.order(created_at: :desc)
    @job_message_counts = message_counts_for(@jobs)
    @reload_necessary = @jobs.any?(&:unfinished?)
  end

  def set_job
    @job = current_user.jobs.find(params[:id])
  end

  def message_counts_for(jobs)
    Message.where(job_id: jobs.select(:id)).group(:job_id).count
  end
end
