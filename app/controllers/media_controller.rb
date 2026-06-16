class MediaController < ApplicationController
  before_action :authenticate_user!

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

  def medium_params
    params.require(:medium).permit(:sourcedb, :sourceid, :media_type, :file)
  end
end
