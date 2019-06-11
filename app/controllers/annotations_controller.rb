require 'fileutils'

class AnnotationsController < ApplicationController
  protect_from_forgery :except => [:create]
  before_filter :authenticate_user!, :except => [:index, :align, :doc_annotations_index, :div_annotations_index, :project_doc_annotations_index, :project_div_annotations_index, :doc_annotations_visualize, :div_annotations_visualize, :project_annotations_tgz]
  include DenotationsHelper

  def index
    message = "The route does not exist.\n"
    respond_to do |format|
      format.html {redirect_to home_path, notice: message}
      format.json {render json: {message:message}, status: :unprocessable_entity}
      format.txt  {render text: message, status: :unprocessable_entity}
    end
  end

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

        context_size = params[:context_size].present? ? params[:context_size].to_i : 0

        options = {}
        options[:discontinuous_span] = params[:discontinuous_span].to_sym if params.has_key? :discontinuous_span
        @annotations = @doc.hannotations(project, @span, context_size, options)

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

      context_size = params[:context_size].present? ? params[:context_size].to_i : 0

      options = {}
      options[:discontinuous_span] = params[:discontinuous_span].to_sym if params.has_key? :discontinuous_span
      @annotations = @doc.hannotations(project, @span, context_size, options)

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

        options = {}
        options[:discontinuous_span] = params[:discontinuous_span].to_sym if params.has_key? :discontinuous_span
        @annotations = @doc.hannotations(@project, @span, context_size, options)

        respond_to do |format|
          format.html {render 'index_in_project'}
          format.json {render json: @annotations}
          format.tsv  {render text: Annotation.hash_to_tsv(@annotations)}
        end
      end

    rescue => e
      respond_to do |format|
        format.html {redirect_to :back, notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
        format.tsv  {render text: 'Error'}
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

      options = {}
      options[:discontinuous_span] = params[:discontinuous_span].to_sym if params.has_key? :discontinuous_span
      @annotations = @doc.hannotations(@project, @span, context_size, options)

      respond_to do |format|
        format.html {render 'index_in_project'}
        format.json {render json: @annotations}
        format.tsv  {render text: Annotation.hash_to_tsv(@annotations)}
      end

    rescue => e
      respond_to do |format|
        format.html {redirect_to (@project.present? ? project_docs_path(@project.name) : home_path), notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
        format.tsv  {render tsv: 'error'}
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
        annotations_visualize
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
      annotations_visualize
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

      annotations = if params[:annotations]
        params[:annotations].symbolize_keys
      elsif params[:text].present?
        {
          text: params[:text],
          denotations: params[:denotations].present? ? params[:denotations] : nil,
          relations: params[:relations].present? ? params[:relations] : nil,
          modification: params[:modification].present? ? params[:modification] : nil,
        }.delete_if{|k, v| v.nil?}
      else
        raise ArgumentError, t('controllers.annotations.create.no_annotation')
      end

      annotations[:sourcedb] = params[:sourcedb]
      annotations[:sourceid] = params[:sourceid]
      annotations[:divid]    = params[:divid]

      annotations = Annotation.normalize!(annotations)

      options = {}
      options[:mode] = params[:mode].present? ? params[:mode] : 'replace'
      options[:prefix] = params[:prefix] if params[:prefix].present?
      options[:span] = {begin: params[:begin].to_i, end: params[:end].to_i} if params[:begin].present? && params[:end].present?

      if params[:divid].present?
        doc = project.docs.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:divid])
        unless doc.present?
          project.add_doc(params[:sourcedb], params[:sourceid])
          expire_fragment("sourcedb_counts_#{project.name}")
          expire_fragment("count_docs_#{project.name}")
          expire_fragment("count_#{params[:sourcedb]}_#{project.name}")
          doc = project.docs.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:divid])
        end
        raise "Could not add the document in the project." unless doc.present?
      else
        divs = project.docs.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
        unless divs.present?
          project.add_doc(params[:sourcedb], params[:sourceid])
          expire_fragment("sourcedb_counts_#{project.name}")
          expire_fragment("count_docs_#{project.name}")
          expire_fragment("count_#{params[:sourcedb]}_#{project.name}")
          divs = project.docs.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
        end
        raise "Could not add the document in the project." unless divs.present?

        if divs.length == 1
          doc = divs[0]
        else
          raise ArgumentError, "A span can be specified only for a single document." if options[:span].present?
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

      doc.set_ascii_body if params[:encoding] == 'ascii'
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

      annotations = Annotation.normalize!(annotations)
      annotations_collection = [annotations]

      if params[:divid].present?
        doc = Doc.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:divid])
        unless doc.present?
          divs, messages = Doc.sequence_docs(params[:sourcedb], [params[:sourceid]])
          raise IOError, "Failed to get the document" unless divs.present?
          expire_fragment("sourcedb_counts")
          expire_fragment("count_#{params[:sourcedb]}")
          doc = divs[params[:divid]]
        end
      else
        divs = Doc.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
        unless divs.present?
          divs, messages = Doc.sequence_docs(params[:sourcedb], [params[:sourceid]])
          raise IOError, "Failed to get the document" unless divs.present?
          expire_fragment("sourcedb_counts")
          expire_fragment("count_#{params[:sourcedb]}")
        end
        doc = divs[0] if divs.length == 1
      end

      annotations = if doc.present?
        Annotation.prepare_annotations(annotations, doc)
      elsif divs.present?
        Annotation.prepare_annotations_divs(annotations, divs)
      else
        raise "Could not find the document."
      end

      respond_to do |format|
        format.json {render json: annotations}
      end

    rescue => e
      respond_to do |format|
        format.json {render :json => {error: e.message}, :status => :unprocessable_entity}
      end
    end
  end

  def obtain
    begin
      project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "Could not find the project: #{params[:project_id]}." unless project.present?

      raise ArgumentError, "Source ID is not specified" unless params[:sourceid].present?
      raise ArgumentError, "Source DB is not specified" unless params[:sourcedb].present?

      # get the annotator
      annotator = if params[:annotator].present?
        Annotator.find(params[:annotator])
      elsif params[:url].present?
        Annotator.new({name:params[:prefix], url:params[:url], method:params[:method], batch_num: 0})
      else
        raise ArgumentError, "Annotator URL is not specified"
      end.as_json.symbolize_keys

      docid = if params[:sourceid].present?
        serial = params[:divid].present? ? params[:divid].to_i : 0
        docids = project.docs.where(sourcedb: params[:sourcedb], sourceid: params[:sourceid], serial:serial).pluck(:id)
        raise ArgumentError, "#{params[:sourcedb]}:#{params[:sourceid]}:#{serial} does not exist in this project." if docids.blank?
        docids.first
      end

      options = {}
      options[:mode] = params[:mode].present? ? params[:mode] : 'replace'
      options[:encoding] = params[:encoding] if params[:encoding].present?
      options[:prefix] = annotator[:name]

      if options[:mode] == 'skip'
        if ProjectDoc.where(project_id:project.id, doc_id:docid).pluck(:denotations_num).first > 0
          raise "There are existing annotations. Obtaining annotation is skipped."
        end
      end

      annotations_col, messages = begin
        project.obtain_annotations([docid], annotator, options)
      rescue RestClient::ExceptionWithResponse => e
        if e.response.code == 303
          options[:retry_after] = e.response.headers[:retry_after].to_i
          options[:try_times] = 3

          # job = RetrieveAnnotationsJob.new(project, e.response.headers[:location], options)
          # job.perform()
          priority = project.jobs.unfinished.count
          delayed_job = Delayed::Job.enqueue RetrieveAnnotationsJob.new(project, e.response.headers[:location], options), priority: priority, queue: :general, run_at: options[:retry_after].seconds.from_now
          Job.create({name:"Retrieve annotations", project_id:project.id, delayed_job_id:delayed_job.id})
          {message: "Annotation request was sent. The result will be retrieved by a background job."}
        elsif e.response.code == 503
          raise RuntimeError, "Service unavailable"
        elsif e.response.code == 404
          raise RuntimeError, "The annotation server does not know the path."
        else
          raise RuntimeError, "Received the following message from the server: #{e.message} "
        end
      rescue => e
        raise RuntimeError, e.message
      end

      annotations_col.delete_if{|e| e.empty?}
      if annotations_col.empty?
        messages << {body: "No annotation was obtained."}
      else
        messages << {body: "Annotations to #{annotations_col.length} doc(s) were obtained."}
      end

      message = messages.empty? ? "" : messages.map{|m| m[:body]}.join("\n") + "\n"

      respond_to do |format|
        format.html {redirect_to :back, notice: message}
        format.json {}
      end
    rescue => e
      respond_to do |format|
        format.html {redirect_to :back, notice: e.message}
        format.json {render status: :service_unavailable}
      end
    end
  end

  def obtain_batch
    begin
      project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "Could not find the project: #{params[:project_id]}." unless project.present?
      raise "Up to 10 jobs can be registered per a project. Please clean your jobs page." unless project.jobs.count < 10

      annotator = if params[:annotator].present?
        Annotator.find(params[:annotator])
      elsif params[:url].present?
        Annotator.new({name:params[:prefix], url:params[:url], method:params[:method], batch_num: 0})
      else
        raise ArgumentError, "Annotator URL is not specified"
      end.as_json.symbolize_keys

      sourceids = if params[:upfile].present?
        File.readlines(params[:upfile].path)
      elsif params[:ids].present?
        params[:ids].split(/[ ,"':|\t\n\r]+/).map{|id| id.strip.sub(/^(PMC|pmc)/, '')}.uniq
      else
        [] # means all the docs in the project
      end
      sourceids.map{|id| id.chomp!}

      raise ArgumentError, "Source DB is not specified." if sourceids.present? && !params['sourcedb'].present?

      options = {}
      options[:mode] = params[:mode].present? ? params[:mode] : 'replace'
      options[:encoding] = params[:encoding] if params[:encoding].present?
      options[:prefix] = annotator[:name]

      sourcedb = params['sourcedb']

      docids = sourceids.inject([]) do |col, sourceid|
        ids = project.docs.where(sourcedb:sourcedb, sourceid:sourceid).pluck(:id)
        raise ArgumentError, "#{sourcedb}:#{sourceid} does not exist in this project." if ids.empty?
        col += ids
      end

      messages = []

      if options[:mode] == 'skip'
        num_skipped = if docids.empty?
          if ProjectDoc.where(project_id:project.id, denotations_num:0).count == 0
            raise RuntimeError, 'Obtaining annotation was skipped because all the docs already had annotations'
          end
          ProjectDoc.where("project_id=#{project.id} and denotations_num > 0").count
        else
          num_docs = docids.length
          docids.delete_if{|docid| ProjectDoc.where(project_id:project.id, doc_id:docid).pluck(:denotations_num).first > 0}
          raise RuntimeError, 'Obtaining annotation was skipped because all the docs already had annotations' if docids.empty?
          num_docs - docids.length
        end

        messages << "#{num_skipped} documents were skipped due to existing annotations." if num_skipped > 0
        options.delete(:mode)
      end

      num_per_job = 100000
      docids_filepaths = begin
        if docids.empty?
          if options[:mode] == 'skip'
            num = ProjectDoc.where(project_id: project.id, denotations_num: 0).count
            n = num / num_per_job
            (0 .. n).collect do |i|
              docids = ProjectDoc.where(project_id: project.id, denotations_num: 0).limit(num_per_job).offset(num_per_job * i + 1).pluck(:doc_id)
              filepath = File.join('tmp', "obtain-#{project.name}-#{i+1}-of-#{n}-#{Time.now.to_s[0..18].gsub(/[ :]/, '-')}.txt")
              File.open(filepath, "w"){|f| f.puts(docids)}
              filepath
            end
          else
            num = ProjectDoc.where(project_id: project.id).count
            n = num / num_per_job
            (0 .. n).collect do |i|
              docids = ProjectDoc.where(project_id: project.id).limit(num_per_job).offset(num_per_job * i).pluck(:doc_id)
              filepath = File.join('tmp', "obtain-#{project.name}-#{i+1}-of-#{n}-#{Time.now.to_s[0..18].gsub(/[ :]/, '-')}.txt")
              File.open(filepath, "w"){|f| f.puts(docids)}
              filepath
            end
          end
        else
          num = docids.length
          n = num / num_per_job
          col = []
          docids.each_slice(num_per_job).with_index do |slice, i|
            filepath = File.join('tmp', "obtain-#{project.name}-#{i+1}-of-#{n}-#{Time.now.to_s[0..18].gsub(/[ :]/, '-')}.txt")
            File.open(filepath, "w"){|f| f.puts(docids)}
            col << filepath
          end
          col
        end
      end

      num_jobs = docids_filepaths.length
      docids_filepaths.each_with_index do |docids_filepath, i|
        priority = project.jobs.unfinished.count
        delayed_job = Delayed::Job.enqueue ObtainAnnotationsJob.new(project, docids_filepath, annotator, options), priority: priority, queue: :upload
        job_name = (num_jobs > 1) ? "Obtain annotations (#{i+1}/#{num_jobs})" : "Obtain annotations"
        Job.create({name:job_name, project_id:project.id, delayed_job_id:delayed_job.id})
      end
      messages << ((num_jobs > 1) ? "#{num_jobs} tasks of 'Obtain annotations' were created." : "The task 'Obtain annotations was created.")

      message = messages.join("\n")

      respond_to do |format|
        format.html {redirect_to :back, notice: message}
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
      raise ArgumentError, "Could not find the project." unless project.present?

      file = params[:upfile]

      filename = file.original_filename
      ext = File.extname(filename).downcase
      ext = '.tar.gz' if ext == '.gz' && filename.end_with?('.tar.gz')
      raise ArgumentError, "Unknown file type: '#{ext}'." unless ['.tgz', '.tar.gz', '.json'].include?(ext)

      raise "Up to 10 jobs can be registered per a project. Please clean your jobs page." unless project.jobs.count < 10

      options = {mode: params[:mode].present? ? params[:mode] : 'replace'}

      filepath = File.join('tmp', "upload-#{params[:project_id]}-#{Time.now.to_s[0..18].gsub(/[ :]/, '-')}#{ext}")
      FileUtils.mv file.path, filepath

      if ext == '.json' && file.size < 10.kilobytes
        job = StoreAnnotationsCollectionUploadJob.new(filepath, project, options)
        res = job.perform()
        notice = "Annotations are successfully uploaded."
      else
        priority = project.jobs.unfinished.count
        delayed_job = Delayed::Job.enqueue StoreAnnotationsCollectionUploadJob.new(filepath, project, options), priority: priority, queue: :upload
        Job.create({name:'Upload annotations', project_id:project.id, delayed_job_id:delayed_job.id})
        notice = "The task, 'Upload annotations', is created."
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
      delayed_job = Delayed::Job.enqueue CreateAnnotationsTgzJob.new(project, {}), priority: priority, queue: :general
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
        if project.editable?(current_user)
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
      raise "Could not find the project." unless project.present?

      doc = if params[:divid].present?
        project.docs.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:divid])
      else
        project.docs.find_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
      end
      raise "Could not find the document." unless doc.present?

      doc.set_ascii_body if params[:encoding] == 'ascii'

      span = {begin: params[:begin].to_i, end: params[:end].to_i} if params[:begin].present? && params[:end].present?
      project.delete_doc_annotations(doc, span)

      respond_to do |format|
        format.html {redirect_to :back, notice: "annotations deleted"}
        format.json {render status: :no_content}
      end
    rescue => e
      redirect_to :back, notice: e.message
    end
  end

  private

  def annotations_visualize
    @span = params[:begin].present? ? {:begin => params[:begin].to_i, :end => params[:end].to_i} : nil
    @doc.set_ascii_body if params[:encoding] == 'ascii'

    params[:project] = params[:projects] if params[:projects].present? && params[:project].blank?

    if params[:project].present?
      project_names = params[:project].split(',').uniq
      @visualize_projects = Array.new
      projects = Project.accessible(current_user).where(['name IN (?)', project_names]).annotations_accessible(current_user)
      project_names.each do |project_name|
        @visualize_projects.push projects.detect{|project| project.name == project_name}
      end

      @non_visualize_projects = @doc.projects.accessible(current_user).annotations_accessible(current_user) - @visualize_projects
    else
      @visualize_projects = @doc.projects.accessible(current_user).annotations_accessible(current_user)
    end

    context_size = params[:context_size].present? ? params[:context_size].to_i : 0

    @annotations = @doc.hannotations(@visualize_projects, @span, context_size)
    @track_annotations = @annotations[:tracks]
    @track_annotations.each {|a| a[:text] = @annotations[:text]}

    respond_to do |format|
      format.html {render 'visualize_tracks'}
      format.json {render json: @annotations}
    end
  end
end
