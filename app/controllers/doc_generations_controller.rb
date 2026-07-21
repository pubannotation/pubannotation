class DocGenerationsController < ApplicationController
  include MediaAccessAuthorizationConcern

  before_action :authenticate_user!
  before_action :authorize_media_access!
  before_action :set_editable_project

  def new
  end

  def create
    medium = Medium.find_by(sourcedb: params.dig(:media, :sourcedb), sourceid: params.dig(:media, :sourceid))
    raise ArgumentError, "Specified media does not exist." unless medium
    raise ArgumentError, "Text generation is supported only for image media." unless medium.image?
    raise ArgumentError, "Specified media has no attached file." unless medium.file.attached?

    caption = medium.file.open { |f| ImageCaptionService.new(f.path).call }

    hdoc = {
      source: params[:source],
      sourcedb: params[:sourcedb],
      sourceid: params[:sourceid],
      username: current_user.username,
      body: caption,
      medium_id: medium.id
    }

    hdoc = Doc.hdoc_normalize!(hdoc, current_user, current_user.root?)
    @doc = Doc.store_hdoc!(hdoc)
    @project.add_doc!(@doc)

    respond_to do |format|
      format.html { redirect_to show_project_sourcedb_sourceid_docs_path(@project.name, hdoc[:sourcedb], hdoc[:sourceid]), notice: t('controllers.shared.successfully_created', model: t('activerecord.models.doc')) }
      format.json { render json: @doc.to_hash, status: :created, location: @doc }
    end
  rescue => e
    respond_to do |format|
      format.html { redirect_to new_project_doc_generation_path(@project.name), notice: e.message }
      format.json { render json: { message: e.message }, status: :unprocessable_entity }
    end
  end

  private

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
