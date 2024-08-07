class ObtainAnnotationsWithCallbackJobsController < ApplicationController
  def new
    @project = Project.editable(current_user).find_by_name(params[:project_id])
  end

  def create
    begin
      project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "Could not find the project: #{params[:project_id]}." unless project.present?
      raise "Up to 10 jobs can be registered per a project. Please clean your jobs page." unless project.jobs.count < 10

      # to determine the annotator
      annotator = Annotator.find(params[:annotator])

      # to determine the options
      options = {}
      options[:mode] = params[:mode]
      options[:prefix] = annotator.name

      # to deterine the docids
      docids =
        if options[:mode] == 'fill'
          # options[:mode] == 'add'
          ProjectDoc.where(project_id:project.id, annotations_updated_at:nil).pluck(:doc_id)
        else
          docids = []
        end


      messages = []

      docids_filepath = begin
        # To update docids according to the options
        if options[:mode] == 'skip'
          num_skipped = if docids.empty?
            if ProjectDoc.where(project_id:project.id, denotations_num:0).count == 0
              raise RuntimeError, 'Obtaining annotation was skipped because all the docs already had annotations'
            end
            docids = ProjectDoc.where(project_id:project.id, denotations_num:0 ).pluck(:doc_id)
            ProjectDoc.where("project_id=#{project.id} and denotations_num > 0").count
          else
            num_docs = docids.length
            docids.delete_if{|docid| ProjectDoc.where(project_id:project.id, doc_id:docid).pluck(:denotations_num).first > 0}
            raise RuntimeError, 'Obtaining annotation was skipped because all the docs already had annotations' if docids.empty?
            num_docs - docids.length
          end

          messages << "#{num_skipped} document(s) was/were skipped due to existing annotations." if num_skipped > 0
          options[:mode] = 'add'
        else
          if docids.empty?
            docids = ProjectDoc.where(project_id:project.id).pluck(:doc_id)
          end
        end

        filepath = File.join('tmp', "obtain-#{project.name}-#{Time.now.to_s[0..18].gsub(/[ :]/, '-')}.txt")
        File.open(filepath, "w"){|f| f.puts(docids)}
        filepath
      end

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
  end
end
