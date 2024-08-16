class ObtainAnnotationsWithCallbackJobsController < ApplicationController
  before_action :authenticate_root_user!, only: :new

  def new
    @project = Project.editable(current_user).find_by_name(params[:project_id])
  end

  def create
    project = Project.editable(current_user).find_by_name(params[:project_id])
    raise "Could not find the project: #{params[:project_id]}." unless project.present?
    raise "Up to 10 jobs can be registered per a project. Please clean your jobs page." unless project.jobs.count < 10

    # to determine the annotator
    annotator = Annotator.find(params[:annotator])
    raise "Could not find annotator: #{params[:annotator]}." unless annotator.present?

    # to determine the docids
    mode, docids, skip_message = project.fetch_docids_to_obtain_annotations_by(params[:mode])

    # to determine the options
    options = {
      mode:,
      prefix: annotator.name
    }

    # to determine the filepath
    filepath = create_file_for(project, docids)

    ObtainAnnotationsWithCallbackJob.perform_later(project, filepath, annotator, options)

    project.update({annotator_id:annotator.id}) if annotator.persisted?

    notice = [skip_message, "The task 'Obtain annotations was created."].compact.join("\n")

    respond_to do |format|
      format.html {redirect_back fallback_location: root_path, notice:}
      format.json {}
    end
  rescue => e
    respond_to do |format|
      format.html {redirect_back fallback_location: root_path, notice: e.message}
      format.json {render status: :service_unavailable}
    end
  end

  private

  def create_file_for(project, docids)
    filepath = File.join('tmp', "obtain-#{project.name}-#{Time.now.to_s[0..18].gsub(/[ :]/, '-')}.txt")
    File.open(filepath, "w"){|f| f.puts(docids)}
    filepath
  end
end
