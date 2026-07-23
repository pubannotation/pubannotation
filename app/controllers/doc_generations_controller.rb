class DocGenerationsController < ApplicationController
  include MediaAccessAuthorizationConcern

  before_action :authenticate_user!
  before_action :authorize_media_access!
  before_action :ensure_editable_project!

  def new
  end

  def create
    medium = Medium.find_by(media_params)
    raise ArgumentError, "Specified media does not exist." unless medium

    active_job = DocGenerationFromMediaJob.perform_later(@project, medium, current_user, doc_attributes)
    notice = t('controllers.docs.text_generation_started', job_name: active_job.job_name)

    respond_to do |format|
      format.html { redirect_to project_docs_path(@project.name), notice: notice }
      format.json { render json: { message: notice, job_name: active_job.job_name }, status: :accepted }
    end
  rescue ArgumentError => e
    render_error(message: e.message, status: :unprocessable_entity)
  end

  private

  def media_params
    params.expect(media: [:sourcedb, :sourceid]).to_h.symbolize_keys
  end

  def doc_attributes
    params.permit(:source, :sourcedb, :sourceid).to_h.symbolize_keys
  end

  def ensure_editable_project!
    @project = Project.editable(current_user).find_by(name: params.expect(:project_id))
    return if @project

    render_project_not_found
  end

  def render_project_not_found
    render_error(
      message: "The project does not exist, or you are not authorized to make a change to the project.",
      status: :not_found,
      redirect_path: home_path
    )
  end

  def render_error(message:, status:, redirect_path: new_project_doc_generation_path(@project.name))
    respond_to do |format|
      format.html { redirect_to redirect_path, notice: message }
      format.json { render json: { message: message }, status: status }
    end
  end
end
