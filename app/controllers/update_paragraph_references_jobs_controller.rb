class UpdateParagraphReferencesJobsController < ApplicationController
  include DocsHelper

  before_action :authenticate_root_user!

  def create
    UpdateParagraphReferencesJob.create_jobs params[:sourcedb], false, 1
    redirect_to update_paragraph_references_job_path
  end

  def show
    @job = job
    if @job

    @messages_grid = initialize_grid @job.messages,
                                     order: :created_at,
                                     order_direction: :desc,
                                     per_page: 10
    else
      @sourcedbs = sourcedb_counts(@project).keys
    end
  end

  def destroy
    UpdateParagraphReferencesJob.destroy_jobs
    redirect_to update_paragraph_references_job_path
  end

  private

  def job
    UpdateParagraphReferencesJob.queued_jobs.first
  end
end
