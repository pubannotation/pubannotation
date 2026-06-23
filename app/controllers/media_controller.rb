class MediaController < ApplicationController
  include MediumHelper

  before_action :authenticate_user!
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

  def bulk_upload
    zip_file = bulk_upload_params
    unless zip_file.present?
      redirect_to new_medium_path, alert: 'Please select a ZIP file.' and return
    end

    service = MediumBulkUploadService.new(zip_file, current_user)
    service.call

    redirect_to media_path, notice: service.result_message
  rescue ArgumentError => e
    redirect_to new_medium_path, alert: e.message
  end

  def destroy
    @medium.destroy
    redirect_to media_path, notice: 'Media was successfully deleted.'
  end

  private

  def bulk_upload_params
    params.expect(:zip_file)
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
