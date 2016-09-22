require 'fileutils'

class AnnotationsController < ApplicationController
  protect_from_forgery :except => [:create]
  before_filter :authenticate_user!, :except => [:align, :doc_annotations_index, :div_annotations_index, :project_doc_annotations_index, :project_div_annotations_index, :doc_annotations_visualize, :div_annotations_visualize, :project_annotations_tgz]
  include DenotationsHelper

  # annotations for doc without project
  def doc_annotations_index
    begin
      divs = Doc.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
      raise "There is no such document." unless divs.present?

      if divs.length > 1
        respond_to do |format|
          format.html {redirect_to doc_sourcedb_sourceid_divs_index_path params}
        end
      else
        @doc = divs[0]
        @span = params[:begin].present? ? {:begin => params[:begin].to_i, :end => params[:end].to_i} : nil
        @doc.set_ascii_body if params[:encoding] == 'ascii'

        params[:project] = params[:projects] if params[:projects].present? && params[:project].blank?

        project = if params[:project].present?
          params[:project].split(',').uniq.map{|project_name| Project.accessible(current_user).find_by_name(project_name)}
        else
          @doc.projects
        end

        project.delete_if{|p| !p.annotations_accessible?(current_user)}

        project = project[0] if project.present? && project.length == 1
        context_size = params[:context_size].present? ? params[:context_size].to_i : 0
        @annotations = @doc.hannotations(project, @span, context_size)

        respond_to do |format|
          format.html {render 'index'}
          format.json {render json: @annotations}
        end
      end

    rescue => e
      respond_to do |format|
        format.html {redirect_to (@project.present? ? project_docs_path(@project.name) : home_path), notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
      end
    end
  end

  # annotations for doc without project
  def div_annotations_index
    begin
      @doc = Doc.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:divid])
      raise "There is no such document." unless @doc.present?

      @span = params[:begin].present? ? {:begin => params[:begin].to_i, :end => params[:end].to_i} : nil

      @doc.set_ascii_body if params[:encoding] == 'ascii'

      params[:project] = params[:projects] if params[:projects].present? && params[:project].blank?

      project = if params[:project].present?
        params[:project].split(',').uniq.map{|project_name| Project.accessible(current_user).find_by_name(project_name)}
      else
        @doc.projects
      end

      project.delete_if{|p| !p.annotations_accessible?(current_user)}

      project = project[0] if project.present? && project.length == 1
      context_size = params[:context_size].present? ? params[:context_size].to_i : 0
      @annotations = @doc.hannotations(project, @span, context_size)

      respond_to do |format|
        format.html {render 'index'}
        format.json {render json: @annotations}
      end

    rescue => e
      respond_to do |format|
        format.html {redirect_to (@project.present? ? project_docs_path(@project.name) : home_path), notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
      end
    end
  end

  def project_doc_annotations_index
    begin
      @project = Project.accessible(current_user).find_by_name(params[:project_id])
      raise "There is no such project." unless @project.present?
      raise "annotations inaccessible" unless @project.annotations_accessible?(current_user)

      unless @project.public?
        authenticate_user!
        raise "There is no such project in your access." unless @project.accessible?(current_user)
      end

      divs = @project.docs.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
      raise "There is no such document in the project." unless divs.present?

      if divs.length > 1
        respond_to do |format|
          format.html {redirect_to index_project_sourcedb_sourceid_divs_docs_path(@project.name, params[:sourcedb], params[:sourceid])}
          format.json {
            divs.each{|div| div.set_ascii_body} if params[:encoding] == 'ascii'
            render json: divs.collect{|div| div.hannotations}
          }
        end
      else
        @doc = divs[0]

        @span = params[:begin].present? ? {:begin => params[:begin].to_i, :end => params[:end].to_i} : nil

        @doc.set_ascii_body if (params[:encoding] == 'ascii')
        # @content = @doc.body.gsub(/\n/, "<br>")

        context_size = params[:context_size].present? ? params[:context_size].to_i : 0
        @annotations = @doc.hannotations(@project, @span, context_size)

        respond_to do |format|
          format.html {render 'index_in_project'}
          format.json {render json: @annotations}
        end
      end

    rescue => e
      respond_to do |format|
        format.html {redirect_to :back, notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
      end
    end
  end

  def project_div_annotations_index
    begin
      @project = Project.accessible(current_user).find_by_name(params[:project_id])
      raise "There is no such project." unless @project.present?

      unless @project.public?
        authenticate_user!
        raise "There is no such project in your access." unless @project.accessible?(current_user)
      end

      @doc = @project.docs.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:divid])
      raise "There is no such document in the project." unless @doc.present?

      @span = params[:begin].present? ? {:begin => params[:begin].to_i, :end => params[:end].to_i} : nil

      @doc.set_ascii_body if (params[:encoding] == 'ascii')

      context_size = params[:context_size].present? ? params[:context_size].to_i : 0
      @annotations = @doc.hannotations(@project, @span, context_size)

      respond_to do |format|
        format.html {render 'index_in_project'}
        format.json {render json: @annotations}
      end

    rescue => e
      respond_to do |format|
        format.html {redirect_to (@project.present? ? project_docs_path(@project.name) : home_path), notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
      end
    end
  end

  def doc_annotations_visualize
    begin
      divs = Doc.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
      raise "There is no such document in the project." unless divs.present?

      if divs.length > 1
        respond_to do |format|
          format.html {redirect_to doc_sourcedb_sourceid_divs_index_path params}
        end
      else
        @doc = divs[0]
        @span = params[:begin].present? ? {:begin => params[:begin].to_i, :end => params[:end].to_i} : nil
        @doc.set_ascii_body if params[:encoding] == 'ascii'

        params[:project] = params[:projects] if params[:projects].present? && params[:project].blank?

        project = if params[:project].present?
          params[:project].split(',').uniq.map{|project_name| Project.accessible(current_user).find_by_name(project_name)}
        else
          @doc.projects
        end

        project.delete_if{|p| !p.annotations_accessible?(current_user)}

        context_size = params[:context_size].present? ? params[:context_size].to_i : 0
        @annotations = @doc.hannotations(project, @span, context_size)

        @track_annotations = @annotations[:tracks]
        @track_annotations.each {|a| a[:text] = @annotations[:text].gsub("\n", " ")}

        respond_to do |format|
          format.html {render 'visualize_tracks'}
          format.json {render json: @annotations}
        end
      end

    rescue => e
      respond_to do |format|
        format.html {redirect_to home_path, notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
      end
    end
  end

  def div_annotations_visualize
    begin
      @doc = Doc.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:divid])
      raise "There is no such document." unless @doc.present?

      @span = params[:begin].present? ? {:begin => params[:begin].to_i, :end => params[:end].to_i} : nil

      @doc.set_ascii_body if params[:encoding] == 'ascii'

      params[:project] = params[:projects] if params[:projects].present? && params[:project].blank?

      project = if params[:project].present?
        params[:project].split(',').uniq.map{|project_name| Project.accessible(current_user).find_by_name(project_name)}
      else
        @doc.projects
      end

      project.delete_if{|p| !p.annotations_accessible?(current_user)}

      context_size = params[:context_size].present? ? params[:context_size].to_i : 0
      @annotations = @doc.hannotations(project, @span, context_size)

      @track_annotations = @annotations[:tracks]
      @track_annotations.each {|a| a[:text] = @annotations[:text]}

      respond_to do |format|
        format.html {render 'visualize_tracks'}
        format.json {render json: @annotations}
      end

    rescue => e
      respond_to do |format|
        format.html {redirect_to home_path, notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
      end
    end
  end

  # POST /annotations
  # POST /annotations.json
  def create
    begin
      project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "There is no such project in your management." unless project.present?

      if params[:annotations]
        annotations = params[:annotations].symbolize_keys
      elsif params[:text].present?
        annotations = {:text => params[:text]}
        annotations[:denotations] = params[:denotations] if params[:denotations].present?
        annotations[:relations] = params[:relations] if params[:relations].present?
        annotations[:modifications] = params[:modifications] if params[:modifications].present?
      else
        raise ArgumentError, t('controllers.annotations.create.no_annotation')
      end

      annotations[:sourcedb] = params[:sourcedb]
      annotations[:sourceid] = params[:sourceid]
      annotations[:divid]    = params[:divid]

      annotations = normalize_annotations!(annotations)

      options = {}
      options[:mode] = params[:mode].present? ? params[:mode] : 'replace'
      options[:prefix] = params[:prefix] if params[:prefix].present?

      annotations_collection = [annotations]

      if params[:divid].present?
        doc = project.docs.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:divid])
        unless doc.present?
          project.add_doc(params[:sourcedb], params[:sourceid])
          expire_fragment("count_docs_#{project.name}")
          expire_fragment("count_#{params[:sourcedb]}_#{project.name}")
          doc = project.docs.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:divid])
        end
        raise "Could not add the document in the project." unless doc.present?
      else
        divs = project.docs.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
        unless divs.present?
          project.add_doc(params[:sourcedb], params[:sourceid])
          expire_fragment("count_docs_#{project.name}")
          expire_fragment("count_#{params[:sourcedb]}_#{project.name}")
          divs = project.docs.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
        end
        raise "Could not add the document in the project." unless divs.present?

        if divs.length == 1
          doc = divs[0]
        else
          priority = project.jobs.unfinished.count
          delayed_job = Delayed::Job.enqueue StoreAnnotationsJob.new(annotations, project, divs, options), priority: priority, queue: :general
          Job.create({name:'Store annotations', project_id:project.id, delayed_job_id:delayed_job.id})

          result = {message: "The task, 'annotations upload: #{params[:sourcedb]}:#{params[:sourceid]}', created."}
          respond_to do |format|
            format.html {redirect_to index_project_sourcedb_sourceid_divs_docs_path(project.name, params[:sourcedb], params[:sourceid])}
            format.json {render json: result}
          end
          return
        end
      end

      result = project.save_annotations(annotations, doc, options)
      notice = "annotations"

      respond_to do |format|
        format.html {redirect_to :back, notice: notice}
        format.json {render json: result, status: :created}
      end

    rescue => e
      respond_to do |format|
        format.html {redirect_to (project.present? ? project_path(project.name) : home_path), notice: e.message}
        format.json {render :json => {error: e.message}, :status => :unprocessable_entity}
      end
    end
  end

  def align
    begin
      if params[:annotations]
        annotations = params[:annotations].symbolize_keys
      elsif params[:text].present?
        annotations = {:text => params[:text]}
        annotations[:denotations] = params[:denotations] if params[:denotations].present?
        annotations[:relations] = params[:relations] if params[:relations].present?
        annotations[:modifications] = params[:modifications] if params[:modifications].present?
      else
        raise ArgumentError, t('controllers.annotations.create.no_annotation')
      end

      annotations[:sourcedb] = params[:sourcedb]
      annotations[:sourceid] = params[:sourceid]
      annotations[:divid]    = params[:divid]

      annotations = normalize_annotations!(annotations)
      annotations_collection = [annotations]

      if params[:divid].present?
        doc = Doc.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:divid])
        unless doc.present?
          divs = Doc.import_from_sequence(params[:sourcedb], params[:sourceid])
          raise IOError, "Failed to get the document" unless divs.present?
          expire_fragment("sourcedb_counts")
          expire_fragment("count_#{params[:sourcedb]}")
          doc = divs[params[:divid]]
        end
      else
        divs = Doc.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
        unless divs.present?
          divs = Doc.import_from_sequence(params[:sourcedb], params[:sourceid])
          raise IOError, "Failed to get the document" unless divs.present?
          expire_fragment("sourcedb_counts")
          expire_fragment("count_#{params[:sourcedb]}")
        end
        doc = divs[0] if divs.length == 1
      end

      annotations = if doc.present?
        Annotation.align_annotations(annotations, doc)
      elsif divs.present?
        Annotation.align_annotations_divs(annotations, divs)
      else
        raise "Could not find the document."
      end

      respond_to do |format|
        format.json {render json: annotations}
      end

    # rescue => e
    #   respond_to do |format|
    #     format.json {render :json => {error: e.message}, :status => :unprocessable_entity}
    #   end
    end
  end

  def obtain
    begin
      project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "There is no such project in your management." unless project.present?

      annotator = if params[:annotator].present?
        Annotator.find(params[:annotator])
      elsif params[:url].present?
        Annotator.new({abbrev:params[:abbrev], url:params[:url], method:params[:method], params:{"text"=>"_text_", "sourcedb"=>"_sourcedb_", "sourceid"=>"_sourceid_"}})
      else
        raise ArgumentError, "Annotator URL is not specified"
      end.as_json

      docids = if params[:sourceid].present?
        serial = params[:divid].present? ? params[:divid].to_i : 0
        docid = project.docs.where(sourcedb: params[:sourcedb], sourceid: params[:sourceid], serial:serial).pluck(:id)
        raise ArgumentError, "#{params[:sourcedb]}:#{params[:sourceid]} does not exist in this project." if docid.blank?
        docid
      elsif params[:ids].present? && params[:sourcedb].present?
        docspecs = params[:ids].split(/[ ,"':|\t\n\r]+/).collect{|id| id.strip}.collect{|id| {sourcedb:params[:sourcedb], sourceid:id}}
        docspecs.each{|d| d[:sourceid].sub!(/^(PMC|pmc)/, '')}
        docspecs.uniq!
        docspecs.inject([]) do |col, docspec|
          ids = project.docs.where(sourcedb: docspec[:sourcedb], sourceid: docspec[:sourceid]).pluck(:id)
          raise ArgumentError, "#{docspec[:sourcedb]}:#{docspec[:sourceid]} does not exist in this project." if ids.blank?
          col += ids
        end
      else
        project.docs.pluck(:id)
      end

      options = {}
      options[:mode] = params[:mode].present? ? params[:mode] : 'replace'
      options[:encoding] = params[:encoding] if params[:encoding].present?

      if docids.length > 1 || params[:run] == 'background'
        priority = project.jobs.unfinished.count
        delayed_job = Delayed::Job.enqueue ObtainAnnotationsJob.new(project, docids, annotator, options), priority: priority, queue: :upload
        Job.create({name:"Obtain annotations", project_id:project.id, delayed_job_id:delayed_job.id})
        notice = "The task 'Obtain annotations' is created."
      elsif docids.length == 1
        doc = Doc.find(docids.first)
        result = project.obtain_annotations(doc, annotator, options)
        num = 0
        unless result.nil?
          num += result.has_key?(:denotations) ? result[:denotations].length : 0
          num += result.has_key?(:relations) ? result[:relations].length : 0
          num += result.has_key?(:modifications) ? result[:modifications].length : 0
        end
        notice = "#{num} annotation(s) obtained."
      else
        notice = "There is no such document."
      end

      respond_to do |format|
        format.html {redirect_to :back, notice: notice}
        format.json {}
      end
    rescue => e
      respond_to do |format|
        format.html {redirect_to :back, notice: e.message}
        format.json {render status: :service_unavailable}
      end
    end
  end

  def create_from_upload
    begin
      project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "There is no such project in your management." unless project.present?

      ext = File.extname(params[:upfile].original_filename)
      if ['.tgz', '.tar.gz', '.json'].include?(ext)
        if project.jobs.count < 10
          options = {mode: params[:mode].present? ? params[:mode] : 'replace'}

          filepath = File.join('tmp', "upload-#{params[:project_id]}-#{Time.now.to_s[0..18].gsub(/[ :]/, '-')}.#{ext}")
          FileUtils.mv params[:upfile].path, filepath

          # job = StoreAnnotationsCollectionUploadJob.new(filepath, project, options)
          # job.perform()

          priority = project.jobs.unfinished.count
          delayed_job = Delayed::Job.enqueue StoreAnnotationsCollectionUploadJob.new(filepath, project, options), priority: priority, queue: :upload
          Job.create({name:'Upload annotations', project_id:project.id, delayed_job_id:delayed_job.id})
          notice = "The task, 'Upload annotations', is created."
        else
          notice = "Up to 10 jobs can be registered per a project. Please clean your jobs page."
        end
      else
        notice = "Unknown file type: '#{ext}'."
      end
    rescue => e
      notice = e.message
    end

    respond_to do |format|
      format.html {redirect_to :back, notice: notice}
      format.json {}
    end
  end

  def delete_from_upload
    begin
      project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "There is no such project in your management." unless project.present?

      ext = File.extname(params[:upfile].original_filename)
      if ['.tgz', '.tar.gz', '.json'].include?(ext)
        if project.jobs.count < 10
          options = {mode: params[:mode].present? ? params[:mode] : 'replace'}

          filepath = File.join('tmp', "delete-#{params[:project_id]}-#{Time.now.to_s[0..18].gsub(/[ :]/, '-')}.#{ext}")
          FileUtils.mv params[:upfile].path, filepath

          priority = project.jobs.unfinished.count
          delayed_job = Delayed::Job.enqueue DeleteAnnotationsFromUploadJob.new(filepath, project, options), priority: priority, queue: :upload
          Job.create({name:'Delete annotations from documents', project_id:project.id, delayed_job_id:delayed_job.id})
          notice = "The task, 'Delete annotations from documents', is created."
        else
          notice = "Up to 10 jobs can be registered per a project. Please clean your jobs page."
        end
      else
        notice = "Unknown file type: '#{ext}'."
      end
    rescue => e
      notice = e.message
    end

    respond_to do |format|
      format.html {redirect_to :back, notice: notice}
      format.json {}
    end
  end


  # redirect to project annotations tgz
  def project_annotations_tgz
    begin
      project = Project.accessible(current_user).find_by_name(params[:project_id])
      raise "There is no such project." unless project.present?

      if File.exist?(project.annotations_tgz_system_path)
        redirect_to project.annotations_tgz_path
      else
        raise "annotation tgz file does not exist."
      end
    rescue => e
      render_status_error(:not_found)
    end
  end

  def import
    begin
      project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "There is no such project in your management: #{params[:project_id]}." unless project.present?

      source_project = Project.find_by_name(params[:select_project])
      raise ArgumentError, "Could not find the project: #{params[:select_project]}." if source_project.nil?
      raise ArgumentError, "You cannot import annotations from itself." if source_project == project
      raise ArgumentError, "The annotations in the project are blinded." if source_project.accessibility == 3

      source_docs = source_project.docs.select{|d| d.serial == 0}
      destin_docs = project.docs.select{|d| d.serial == 0}
      shared_docs = source_docs & destin_docs

      raise ArgumentError, "There is no shared document with the project, #{source_project.name}" if shared_docs.length == 0
      raise ArgumentError, "For a performance reason, current implementation limits this feature to work for less than 3,000 documents." if shared_docs.length > 3000

      docids = shared_docs.collect{|d| d.id}

      priority = project.jobs.unfinished.count
      delayed_job = Delayed::Job.enqueue ImportAnnotationsJob.new(source_project, project), priority: priority, queue: :general
      Job.create({name:"Import annotations from #{source_project.name}", project_id:project.id, delayed_job_id:delayed_job.id})
      message = "The task, 'import annotations from the project, #{source_project.name}', is created."

    rescue => e
      message = e.message
    end

    respond_to do |format|
      format.html {redirect_to project_path(project.name), notice: message}
      format.json {render json:{message:message}}
    end
  end

  def create_project_annotations_tgz
    begin
      project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "There is no such project in your management." unless project.present?
      priority = project.jobs.unfinished.count
      delayed_job = Delayed::Job.enqueue CreateAnnotationsTgzJob.new(project), priority: priority, queue: :general
      Job.create({name:'Create annotations tarball', project_id:project.id, delayed_job_id:delayed_job.id})
      redirect_to :back, notice: "The task 'Create annotations tarball' is created."
    rescue => e
      redirect_to home_path, notice: e.message
    end
  end


  def delete_project_annotations_tgz
    begin
      status_error = false
      project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "There is no such project." unless project.present?

      if File.exist?(project.annotations_tgz_system_path)
        if project.user == current_user 
          File.unlink(project.annotations_tgz_system_path)
          flash[:notice] = t('views.shared.download.deleted')
        else
          status_error = true
          render_status_error(:forbidden)
        end
      else
        status_error = true
        render_status_error(:not_found)
      end
    rescue => e
      flash[:notice] = e.message
    ensure
      redirect_to :back if status_error == false
    end
  end

  def project_annotations_rdf
    begin
      project = Project.accessible(current_user).find_by_name(params[:project_id])
      raise "There is no such project." unless project.present?

      if File.exist?(project.annotations_rdf_system_path)
        # redirect_to "/annotations/#{project.annotations_rdf_file_name}"
        redirect_to project.annotations_rdf_path
      else
        raise "annotation rdf file does not exist."
      end
    rescue => e
      render_status_error(:not_found)
    end
  end

  def delete_project_annotations_rdf
    begin
      status_error = false
      project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "There is no such project." unless project.present?

      if File.exist?(project.annotations_rdf_system_path)
        if project.user == current_user 
          File.unlink(project.annotations_rdf_system_path)
          flash[:notice] = t('views.shared.rdf.deleted')
        else
          status_error = true
          render_status_error(:forbidden)
        end
      else
        status_error = true
        render_status_error(:not_found)
      end
    rescue => e
      flash[:notice] = e.message
    ensure
      redirect_to :back if status_error == false
    end
  end

  def destroy
    begin
      project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "There is no such project in your management." unless project.present?

      doc = if params[:divid].present?
        project.docs.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:divid])
      else
        project.docs.find_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
      end
      raise "There is no such document in the project." unless doc.present?

      span = params[:begin].present? ? {:begin => params[:begin].to_i, :end => params[:end].to_i} : nil

      doc.set_ascii_body if (params[:encoding] == 'ascii')
      denotations = doc.get_denotations(project, span)
      denotations.each{|d| d.destroy}

      respond_to do |format|
        format.html {redirect_to :back, status: :see_other, notice: "annotations deleted"}
        format.json {render status: :no_content}
      end
    end
  end

end
