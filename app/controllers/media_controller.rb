class MediaController < ApplicationController
  before_action :authenticate_user!
  before_action :set_medium, only: [:show]

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
    @medium.content_type = params[:medium][:file]&.content_type

    if @medium.save
      redirect_to new_medium_path, notice: 'Media was successfully uploaded.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_medium
    @medium = Medium.find_by!(sourcedb: params[:sourcedb], sourceid: params[:sourceid])
  end

  def medium_params
    params.expect(medium: [:sourcedb, :sourceid, :media_type, :file])
  end
end
