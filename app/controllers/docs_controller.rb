require 'fileutils'
require 'zip/zip'

class DocsController < ApplicationController
  protect_from_forgery :except => [:create]
  before_filter :authenticate_user!, :only => [:new, :create, :create_from_upload, :edit, :update, :destroy, :project_delete_doc, :project_delete_all_docs]
  before_filter :http_basic_authenticate, :only => :create, :if => Proc.new{|c| c.request.format == 'application/jsonrequest'}
  skip_before_filter :authenticate_user!, :verify_authenticity_token, :if => Proc.new{|c| c.request.format == 'application/jsonrequest'}

  cache_sweeper :doc_sweeper
  autocomplete :doc, :sourcedb

  def index
    begin
      if params[:project_id].present?
        @project = Project.accessible(current_user).find_by_name(params[:project_id])
        raise "Could not find the project." unless @project.present?
      end

      @sourcedb = params[:sourcedb]

      page, per = if params[:format] && (params[:format] == "json" || params[:format] == "tsv")
        params.delete(:page)
        [1, 1000]
      else
        [params[:page], 10]
      end

      htexts = nil
      @docs = if params[:keywords].present?
        project_id = @project.nil? ? nil : @project.id
        search_results = Doc.search_docs({body: params[:keywords].strip.downcase, project_id: project_id, sourcedb: @sourcedb, page:page, per:per})
        @search_count = search_results.results.total
        htexts = search_results.results.map{|r| {text: r.highlight.body}}
        search_results.records
      else
        sort_order = sort_order(Doc)
        if params[:randomize]
          sort_order = sort_order ? sort_order + ', ' : ''
          sort_order += 'random()'
        end

        if @project.present?
          if @sourcedb.present?
            if Doc.is_mdoc_sourcedb(@sourcedb)
              @project.docs.where(sourcedb: @sourcedb, serial: 0).order(sort_order).simple_paginate(page, per)
            else
              @project.docs.where(sourcedb: @sourcedb).order(sort_order).simple_paginate(page, per)
            end
          else
            @project.docs.where(serial: 0).order(sort_order).simple_paginate(page, per)
          end
        else
          if @sourcedb.present?
            if Doc.is_mdoc_sourcedb(@sourcedb)
              Doc.where(sourcedb: @sourcedb, serial: 0).order(sort_order).simple_paginate(page, per)
            else
              Doc.where(sourcedb: @sourcedb).order(sort_order).simple_paginate(page, per)
            end
          else
            Doc.where(serial: 0).order(sort_order).simple_paginate(page, per)
          end
        end
      end

      respond_to do |format|
        format.html {
          if htexts
            htexts = htexts.map{|h| h[:text].first}
            @docs = @docs.zip(htexts).each{|d,t| d.body = t}.map{|d,t| d}
          end
        }
        format.json {
          hdocs = @docs.map{|d| d.to_list_hash('doc')}
          if htexts
            hdocs = hdocs.zip(htexts).map{|d| d.reduce(:merge)}
          end
          render json: hdocs
        }
        format.tsv  {
          hdocs = @docs.map{|d| d.to_list_hash('doc')}
          if htexts
            htexts.each{|h| h[:text] = h[:text].first}
            hdocs = hdocs.zip(htexts).map{|d| d.reduce(:merge)}
          end
          render text: Doc.hash_to_tsv(hdocs)
        }
      end
    rescue => e
      respond_to do |format|
        format.html {redirect_to (@project.present? ? project_path(@project.name) : home_path), notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
        format.txt  {render text: message, status: :unprocessable_entity}
      end
    end
  end

  def records
    if params[:project_id]
      @project, notice = get_project(params[:project_id])
      @new_doc_src = new_project_doc_path
      if @project
        @docs = @project.docs.order('sourcedb ASC').order('sourceid ASC').order('serial ASC')
      else
        @docs = nil
      end
    else
      @docs = Doc.order('sourcedb ASC').order('sourceid ASC').order('serial ASC')
      @new_doc_src = new_doc_path
    end

    @docs.each{|doc| doc.set_ascii_body} if (params[:encoding] == 'ascii')

    respond_to do |format|
      if @docs
        format.html { @docs = @docs.page(params[:page]) }
        format.json { render json: @docs }
        format.txt  {
          file_name = (@project)? @project.name + ".zip" : "docs.zip"
          t = Tempfile.new("pubann-temp-filename-#{Time.now}")
          Zip::ZipOutputStream.open(t.path) do |z|
            @docs.each do |doc|
              title = "%s-%s-%02d-%s" % [doc.sourcedb, doc.sourceid, doc.serial, doc.section]
              title.sub!(/\.$/, '')
              title.gsub!(' ', '_')
              title += ".txt" unless title.end_with?(".txt")
              z.put_next_entry(title)
              z.print doc.body
            end
          end
          send_file t.path, :type => 'application/zip',
                            :disposition => 'attachment',
                            :filename => file_name
          t.close

          # texts = @docs.collect{|doc| doc.body}
          # render text: texts.join("\n----------\n")
        }
      else
        format.html { flash[:notice] = notice }
        format.json { head :unprocessable_entity }
        format.txt  { head :unprocessable_entity }
      end
    end
  end
 
  def sourcedb_index
    begin
      if params[:project_id].present?
        @project = Project.accessible(current_user).find_by_name(params[:project_id])
        raise "There is no such project." unless @project.present?
      end

    rescue => e
      respond_to do |format|
        format.html {redirect_to :back, notice: e.message}
      end
    end
  end 

  def show
    begin
      divs = if params[:id].present?
        [Doc.find(params[:id])]
      else
        Doc.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
      end
      raise "There is no such document." unless divs.present?

      if divs.length > 1
        respond_to do |format|
          format.html {redirect_to doc_sourcedb_sourceid_divs_index_path params}
          format.json {
            divs.each{|div| div.set_ascii_body} if params[:encoding] == 'ascii'
            render json: divs.collect{|div| div.to_hash}
          }
          format.txt {
            divs.each{|div| div.set_ascii_body} if params[:encoding] == 'ascii'
            render text: divs.collect{|div| div.body}.join("\n")
          }
        end
      else
        @doc = divs[0]

        @doc.set_ascii_body if params[:encoding] == 'ascii'
        @content = @doc.body.gsub(/\n/, "<br>")

        get_docs_projects

        respond_to do |format|
          format.html
          format.json {render json: @doc.to_hash}
          format.txt  {render text: @doc.body}
        end
      end

    rescue => e
      respond_to do |format|
        format.html {redirect_to (@project.present? ? project_docs_path(@project.name) : home_path), notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
        format.txt  {render text: message, status: :unprocessable_entity}
      end
    end
  end

  def show_in_project
    begin
      @project = Project.accessible(current_user).find_by_name(params[:project_id])
      raise "Could not find the project." unless @project.present?

      divs = @project.docs.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
      raise "Could not find the document within this project." unless divs.present?

      if divs.length > 1
        respond_to do |format|
          format.html {redirect_to index_project_sourcedb_sourceid_divs_docs_path(@project.name, params[:sourcedb], params[:sourceid])}
          format.json {
            divs.each{|div| div.set_ascii_body} if params[:encoding] == 'ascii'
            render json: divs.collect{|div| div.body}
          }
          format.txt {
            divs.each{|div| div.set_ascii_body} if params[:encoding] == 'ascii'
            render text: divs.collect{|div| div.body}.join("\n")
          }
        end
      else
        @doc = divs[0]

        @doc.set_ascii_body if (params[:encoding] == 'ascii')
        @content = @doc.body.gsub(/\n/, "<br>")

        respond_to do |format|
          format.html
          format.json {render json: @doc.to_hash}
          format.txt  {render text: @doc.body}
        end
      end

    rescue => e
      respond_to do |format|
        format.html {redirect_to (@project.present? ? project_docs_path(@project.name) : home_path), notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
        format.txt  {render status: :unprocessable_entity}
      end
    end
  end

  def open
    params[:sourceid].strip!
    begin
      if params[:project_id].present?
        project = Project.accessible(current_user).find_by_name(params[:project_id])
        raise "Could not find the project." unless project.present?

        divs = project.docs.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
        raise "Could not find the document within this project." unless divs.present?

        respond_to do |format|
          format.html {redirect_to show_project_sourcedb_sourceid_docs_path(params[:project_id], params[:sourcedb], params[:sourceid])}
        end
      else
        divs = Doc.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
        raise "Could not find the document within PubAnnotation." unless divs.present?

        respond_to do |format|
          format.html {redirect_to doc_sourcedb_sourceid_show_path(params[:sourcedb], params[:sourceid])}
        end
      end

    rescue => e
      respond_to do |format|
        format.html {redirect_to :back, notice: e.message}
      end
    end
  end

  # GET /docs/new
  # GET /docs/new.json
  def new
    @doc = Doc.new
    begin 
      @project = get_project2(params[:project_id])
    rescue => e
      notice = e.message
    end
    respond_to do |format|
      format.html # new.html.erb
      format.json {render json: @doc.to_hash}
    end
  end

  # POST /docs
  # POST /docs.json
  # Creation of document is only allowed for single division documents.
  def create
    begin
      raise ArgumentError, "project id has to be specified." unless params[:project_id].present?

      @project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "The project does not exist, or you are not authorized to make a change to the project.\n" unless @project.present?

      doc_hash = if params[:doc].present? && params[:commit].present?
        params[:doc] 
      else
        text = if params[:text]
          params[:text]
        elsif request.content_type =~ /text/
          request.body.read
        end

        if text
          {
            source: params[:source],
            sourcedb: params[:sourcedb] || '',
            sourceid: params[:sourceid],
            serial: params[:divid] || 0,
            section: params[:section],
            body: text
          }
        else
          raise ArgumentError, "A block of text has to be sent."
        end
      end

      doc_hash = Doc.hdoc_normalize!(doc_hash, current_user, current_user.root?)

      @doc = Doc.new(doc_hash)
      if @doc.save
        @doc.projects << @project
        expire_fragment("sourcedb_counts_#{@project.name}")
        expire_fragment("count_docs_#{@project.name}")
        expire_fragment("count_#{@doc.sourcedb}_#{@project.name}")
      else
        raise IOError, "could not create the document."
      end

      respond_to do |format|
        format.html { redirect_to show_project_sourcedb_sourceid_docs_path(@project.name, doc_hash[:sourcedb], doc_hash[:sourceid]), notice: t('controllers.shared.successfully_created', :model => t('activerecord.models.doc')) }
        format.json { render json: @doc, status: :created, location: @doc }
      end
    rescue => e
      logger.error e.message
      logger.error e.backtrace.join("\n")

      respond_to do |format|
        format.html { redirect_to new_project_doc_path(@project.name), notice: e.message }
        format.json { render json: {message: e.message}, status: :unprocessable_entity }
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
      raise ArgumentError, "Unknown file type: '#{ext}'." unless ['.tgz', '.tar.gz', '.json', '.txt'].include?(ext)

      options = {
        mode: params[:mode].present? ? params[:mode].to_sym : :update,
        root: current_user.root?
      }

      dirpath = File.join('tmp/uploads', "#{params[:project_id]}-#{Time.now.to_s[0..18].gsub(/[ :]/, '-')}")
      FileUtils.mkdir_p dirpath
      FileUtils.mv file.path, File.join(dirpath, filename)

      if ['.json', '.txt'].include?(ext) && file.size < 100.kilobytes
        job = UploadDocsJob.new(dirpath, project, options)
        res = job.perform()
        notice = "Documents are successfully uploaded."
      else
        raise "Up to 10 jobs can be registered per a project. Please clean your jobs page." unless project.jobs.count < 10
        priority = project.jobs.unfinished.count

        # job = UploadDocsJob.new(dirpath, project, options)
        # job.perform()

        delayed_job = Delayed::Job.enqueue UploadDocsJob.new(dirpath, project, options), priority: priority, queue: :upload
        task_name = "Upload documents: #{filename}"
        Job.create({name:task_name, project_id:project.id, delayed_job_id:delayed_job.id})
        notice = "The task, '#{task_name}', is created."
      end
    rescue => e
      notice = e.message
    end

    respond_to do |format|
      format.html {redirect_to :back, notice: notice}
      format.json {}
    end
  end

  # GET /docs/1/edit
  def edit
    begin
      raise RuntimeError, "Not authorized" unless current_user && current_user.root? == true

      divs = Doc.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
      raise "There is no such document" unless divs.present?

      if divs.length > 1
        respond_to do |format|
          format.html {redirect_to :back}
        end
      else
        @doc = divs[0]
      end
    rescue => e
      respond_to do |format|
        format.html {redirect_to (@project.present? ? project_docs_path(@project.name) : home_path), notice: e.message}
      end
    end
  end

  # PUT /docs/1
  # PUT /docs/1.json
  def update
    raise RuntimeError, "Not authorized" unless current_user && current_user.root? == true

    params[:doc][:body].gsub!(/\r\n/, "\n")
    @doc = Doc.find(params[:id])

    respond_to do |format|
      if @doc.update_attributes(params[:doc])
        format.html { redirect_to @doc, notice: t('controllers.shared.successfully_updated', :model => t('activerecord.models.doc')) }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @doc.errors, status: :unprocessable_entity }
      end
    end
  end

  # add new docs to a project
  def add_from_upload
    begin
      project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "The project does not exist, or you are not authorized to make a change to the project.\n" unless project.present?
      raise ArgumentError, "sourcedb is not specified." unless params["sourcedb"].present?

      sourcedb = params["sourcedb"]
      filename = params[:upfile].original_filename
      ext = File.extname(filename)
      raise ArgumentError, "Unknown file type: '#{ext}'." unless ['.txt'].include?(ext)

      raise "Up to 10 jobs can be registered per a project. Please clean your jobs page." unless project.jobs.count < 10

      filepath = File.join('tmp', "add-docs-to-#{params[:project_id]}-#{Time.now.to_s[0..18].gsub(/[ :]/, '-')}#{ext}")
      FileUtils.mv params[:upfile].path, filepath

      # job = AddDocsToProjectFromUploadJob.new(sourcedb, filepath, project)
      # job.perform()

      priority = project.jobs.unfinished.count
      delayed_job = Delayed::Job.enqueue AddDocsToProjectFromUploadJob.new(sourcedb, filepath, project), priority: priority, queue: :general
      job = Job.create({name:'Add docs to project from upload', project_id:project.id, delayed_job_id:delayed_job.id})
      message = "The task, 'Add docs to project from upload', is created."

      respond_to do |format|
        format.html {redirect_to :back, notice: message}
        format.json {render json: {message: message, task_location: project_job_url(project.name, job.id, format: :json)}, status: :ok}
      end
    rescue => e
      respond_to do |format|
        format.html {redirect_to :back, notice: e.message}
        format.json {render json: {message: e.message}, status: :unprocessable_entity}
      end
    end
  end

  # add new docs to a project
  def add
    begin
      project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "The project does not exist, or you are not authorized to make a change to the project.\n" unless project.present?

      # get the docspecs list
      docspecs =  if params["_json"] && params["_json"].class == Array
                    params["_json"].collect{|d| d.symbolize_keys}
                  elsif params["sourcedb"].present? && params["sourceid"].present?
                    [{sourcedb:params["sourcedb"], sourceid:params["sourceid"]}]
                  elsif params[:ids].present? && params[:sourcedb].present?
                    params[:ids].strip.split(/[ ,"':|\t\n\r]+/).collect{|id| id.strip}.collect{|id| {sourcedb:params[:sourcedb], sourceid:id}}
                  else
                    []
                  end

      raise ArgumentError, "no valid document specification found." if docspecs.empty?

      docspecs.each{|d| d[:sourceid].sub!(/^(PMC|pmc)/, '')}
      docspecs.uniq!

      if docspecs.length == 1
        docspec = docspecs.first
        begin
          divs = project.add_doc(docspec[:sourcedb], docspec[:sourceid])
          raise ArgumentError, "The document already exists." if divs.nil?
          expire_fragment("sourcedb_counts_#{project.name}")
          expire_fragment("count_docs_#{project.name}")
          expire_fragment("count_#{docspec[:sourcedb]}_#{project.name}")
          message = "#{docspec[:sourcedb]}:#{docspec[:sourceid]} - added."
        rescue => e
          message = "#{docspec[:sourcedb]}:#{docspec[:sourceid]} - #{e.message}"
        end
      else
        # delayed_job = AddDocsToProjectJob.new(docspecs, project)
        # delayed_job.perform()

        priority = project.jobs.unfinished.count
        delayed_job = Delayed::Job.enqueue AddDocsToProjectJob.new(docspecs, project), priority: priority, queue: :general
        Job.create({name:'Add docs to project', project_id:project.id, delayed_job_id:delayed_job.id})
        message = "The task, 'add documents to the project', is created."
      end

    rescue => e
      message = e.message
    end

    respond_to do |format|
      format.html {redirect_to :back, notice: message}
      format.json {render json:{message:message}}
    end
  end

  def import
    message = begin
      project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "The project (#{params[:project_id]}) does not exist, or you are not authorized to make a change to it.\n" unless project.present?

      source_project = Project.find_by_name(params["select_project"])
      raise ArgumentError, "The project (#{params["select_project"]}) does not exist, or you are not authorized to access it.\n" unless source_project.present?

      raise ArgumentError, "You cannot import documents from itself." if source_project == project

      docids = source_project.docs.pluck(:id) - project.docs.pluck(:id)

      if docids.empty?
        "There is no document to import from the project, '#{params["select_project"]}'."
      else
        num_source_docs = source_project.docs.count
        num_skip = num_source_docs - docids.length

        docids_file = Tempfile.new("docids")
        docids_file.puts docids
        docids_file.close

        priority = project.jobs.unfinished.count
        delayed_job = Delayed::Job.enqueue ImportDocsJob.new(docids_file.path, project), priority: priority, queue: :general
        Job.create({name:'Import docs to project', project_id:project.id, delayed_job_id:delayed_job.id})

        m = ""
        m += "#{num_skip} docs were skipped due to duplication." if num_skip > 0
        m += "The task, 'import documents to the project', is created."
      end
    rescue => e
      e.message
    end

    respond_to do |format|
      format.html {redirect_to :back, notice: message}
      format.json {render json:{message:message}}
    end
  end

  def uptodate
    raise RuntimeError, "Not authorized" unless current_user && current_user.root? == true

    divs = params[:sourceid].present? ? Doc.where(sourcedb:params[:sourcedb], sourceid:params[:sourceid]).order(:serial) : nil
    raise ArgumentError, "There is no such document." if params[:sourceid].present? && !divs.present?

    Doc.uptodate(divs)
    message = "The document #{divs[0].descriptor} is successfully updated."
    redirect_to doc_sourcedb_sourceid_show_path(params[:sourcedb], params[:sourceid]), notice: message
  rescue => e
    redirect_to :back, notice: e.message
  end

  # DELETE /docs/sourcedb/:sourcedb/sourceid/:sourceid
  def delete
    raise SecurityError, "Not authorized" unless current_user && current_user.root? == true

    divs = Doc.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
    raise "There is no such document." unless divs.present?

    sourcedb = divs.first.sourcedb
    divs.each{|div| div.destroy}

    redirect_to doc_sourcedb_index_path(sourcedb)
  end

  # DELETE /docs/1
  # DELETE /docs/1.json
  def destroy
    begin
      doc = Doc.find(params[:id])
      if params[:project_id].present?
        project = Project.editable(current_user).find_by_name(params[:project_id])
        raise "There is no such project in your management." unless project.present?
        project.docs.delete(doc)
        expire_fragment("sourcedb_counts_#{project.name}")
        expire_fragment("count_docs_#{project.name}")
        expire_fragment("count_#{doc.sourcedb}_#{project.name}")

        redirect_path = records_project_docs_path(params[:project_id])
      else
        raise SecurityError, "Not authorized" unless current_user && current_user.root? == true
        doc.destroy
        redirect_path = home_path
      end

      message = 'the document is deleted from the project.'
      respond_to do |format|
        format.html { redirect_to redirect_path }
        format.json { render json: {message: message} }
        format.txt  { render text: message }
      end
    rescue => e
      respond_to do |format|
        format.html { redirect_to redirect_path, notice: e.message }
        format.json { render json: {message: e.message}, status: :unprocessable_entity }
        format.txt  { render text: e.message, status: :unprocessable_entity }
      end
    end
  end

  def project_delete_doc
    begin
      project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "The project does not exist, or you are not authorized to make a change to the project.\n" unless project.present?

      divs = project.docs.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
      raise "The document does not exist in the project.\n" unless divs.present?

      divs.each{|div| project.delete_doc(div)}
      expire_fragment("sourcedb_counts_#{project.name}")
      expire_fragment("count_docs_#{project.name}")
      expire_fragment("count_#{params[:sourcedb]}_#{project.name}")

      message = "the document is deleted from the project.\n"

      respond_to do |format|
        format.html { redirect_to project_docs_path(project.name), notice:message }
        format.json { render json: {message: message} }
        format.txt  { render text: message }
      end
    rescue => e
      respond_to do |format|
        format.html { redirect_to project_docs_path(project.name), notice:e.message }
        format.json { render json: {message: e.message}, status: :unprocessable_entity }
        format.txt  { render text: e.message, status: :unprocessable_entity }
      end
    end
  end

  def store_span_rdf
    begin
      raise RuntimeError, "Not authorized" unless current_user && current_user.root? == true

      projects = Project.for_index
      docids = projects.inject([]){|col, p| (col + p.docs.pluck(:id))}.uniq
      system = Project.find_by_name('system-maintenance')

      delayed_job = Delayed::Job.enqueue StoreRdfizedSpansJob.new(system, docids, Pubann::Application.config.rdfizer_spans), queue: :general
      Job.create({name:"Store RDFized spans for selected projects", project_id:system.id, delayed_job_id:delayed_job.id})
    rescue => e
      flash[:notice] = e.message
    end
    redirect_to project_path('system-maintenance')
  end

  def update_numbers
    begin
      raise RuntimeError, "Not authorized" unless current_user && current_user.root? == true
      system = Project.find_by_name('system-maintenance')

      delayed_job = Delayed::Job.enqueue UpdateAnnotationNumbersJob.new(nil), queue: :general
      Job.create({name:"Update annotation numbers of each document", project_id:system.id, delayed_job_id:delayed_job.id})

      result = {message: "The task, 'update annotation numbers of each document', created."}
      redirect_to project_path('system-maintenance')
    rescue => e
      flash[:notice] = e.message
      redirect_to home_path
    end
  end

  # def autocomplete_sourcedb
  #   render :json => Doc.where(['LOWER(sourcedb) like ?', "%#{params[:term].downcase}%"]).collect{|doc| doc.sourcedb}.uniq
  # end

end
