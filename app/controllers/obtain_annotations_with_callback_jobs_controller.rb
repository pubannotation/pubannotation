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
    mode, docids, messages = docids_for(project, params[:mode])

    # to determine the options
    options = {
      mode:,
      prefix: annotator.name
    }

    # to determine the docids_filepath
    docids_filepath = filepath_for(project, docids)

    ObtainAnnotationsWithCallbackJob.perform_later(project, docids_filepath, annotator, options)

    project.update({annotator_id:annotator.id}) if annotator.persisted?

    messages << "The task 'Obtain annotations was created."
    message = messages.join("\n")

    respond_to do |format|
      format.html {redirect_back fallback_location: root_path, notice: message}
      format.json {}
    end
  rescue => e
    respond_to do |format|
      format.html {redirect_back fallback_location: root_path, notice: e.message}
      format.json {render status: :service_unavailable}
    end
  end

  private

  def docids_for(project, mode)
    case mode
    when 'fill'
      docids = project.docs_without_annotation.pluck(:id)
      mode = 'add'
    when 'skip'
      if project.project_docs.without_denotations.count == 0
        raise RuntimeError, 'Obtaining annotation was skipped because all the docs already had annotations'
      end
      docids = project.project_docs.without_denotations.pluck(:doc_id)
      mode = 'add'
      num_skipped = project.project_docs.with_denotations.count
      message = "#{num_skipped} document(s) was/were skipped due to existing annotations." if num_skipped > 0
    else
      docids = project.project_docs.pluck(:doc_id)
    end

    [mode, docids, [message].compact]
  end

  def filepath_for(project, docids)
    filepath = File.join('tmp', "obtain-#{project.name}-#{Time.now.to_s[0..18].gsub(/[ :]/, '-')}.txt")
    File.open(filepath, "w"){|f| f.puts(docids)}
    filepath
  end
end
