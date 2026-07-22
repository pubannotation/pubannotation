class DocGenerationsController < ApplicationController
  include MediaAccessAuthorizationConcern

  before_action :authenticate_user!
  before_action :authorize_media_access!
  before_action :set_editable_project

  def new
  end

  def create
    medium = Medium.find_by(media_params)
    raise ArgumentError, "Specified media does not exist." unless medium

    @doc = DocGenerationFromMedia.new(
      project: @project,
      medium: medium,
      user: current_user,
      attributes: doc_attributes
    ).call

    respond_to do |format|
      format.html { redirect_to show_project_sourcedb_sourceid_docs_path(@project.name, @doc.sourcedb, @doc.sourceid), notice: t('controllers.shared.successfully_created', model: t('activerecord.models.doc')) }
      format.json { render json: @doc.to_hash, status: :created, location: @doc }
    end
  rescue ArgumentError => e
    respond_to do |format|
      format.html { redirect_to new_project_doc_generation_path(@project.name), notice: e.message }
      format.json { render json: { message: e.message }, status: :unprocessable_entity }
    end
  end

  private

  def media_params
    params.expect(media: [:sourcedb, :sourceid]).to_h.symbolize_keys
  end

  def doc_attributes
    params.permit(:source, :sourcedb, :sourceid).to_h.symbolize_keys
  end

  def set_editable_project
    @project = Project.editable(current_user).find_by_name(params[:project_id])
    return if @project.present?

    message = "The project does not exist, or you are not authorized to make a change to the project."
    respond_to do |format|
      format.html { redirect_to home_path, notice: message }
      format.json { render json: { message: message }, status: :unprocessable_entity }
    end
  end
end
