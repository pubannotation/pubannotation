class MediaController < ApplicationController
  include MediumHelper

  before_action :authenticate_user!
  before_action :authorize_media_access!
  before_action :set_medium, only: [:show, :destroy]
  before_action :authorize_destroy!, only: [:destroy]

  def index
    @media_grid = initialize_grid(Medium, order: 'media.created_at', order_direction: 'desc')
  end

  def show
  end

  def new
    @medium = Medium.new
  end

  def create
    @medium = Medium.new(medium_params)
    @medium.user = current_user
    @medium.content_type = params[:medium][:file]&.content_type

    if @medium.save
      redirect_to new_medium_path, notice: 'Media was successfully uploaded.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def jobs
    @jobs = current_user.jobs.order(created_at: :desc)
  end

  def latest_jobs_table
    @jobs = current_user.jobs.order(created_at: :desc)
    render partial: 'jobs_table'
  end

  def clear_finished_jobs
    Job.batch_destroy_finished(current_user)
    redirect_to jobs_media_path, notice: 'Finished jobs cleared.'
  end

  def bulk_upload
    MediaBulkUploadJob.enqueue(current_user, bulk_upload_params)
    redirect_to new_medium_path, notice: 'Bulk upload job has been queued.'
  end

  def destroy
    @medium.destroy
    redirect_to media_path, notice: 'Media was successfully deleted.'
  end

  private

  def bulk_upload_params
    params.expect(:zip_file)
  end

  def authorize_media_access!
    unless current_user&.can_access_media?
      render_status_error(:forbidden)
    end
  end

  def set_medium
    @medium = Medium.find_by!(sourcedb: params[:sourcedb], sourceid: params[:sourceid])
  end

  def authorize_destroy!
    unless current_user_owns_medium?(@medium)
      redirect_to show_media_path(sourcedb: @medium.sourcedb, sourceid: @medium.sourceid), alert: 'You are not authorized to delete this media.'
    end
  end

  def medium_params
    params.expect(medium: [:sourcedb, :sourceid, :media_type, :file])
  end
end
