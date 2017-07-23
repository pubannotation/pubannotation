class ProjectsController < ApplicationController
  before_filter :updatable?, :only => [:edit, :update]
  before_filter :destroyable?, :only => :destroy
  before_filter :authenticate_user!, :except => [:index, :show, :autocomplete_pmcdoc_sourceid, :autocomplete_pmdoc_sourceid, :autocomplete_project_author, :search]
  # JSON POST
  before_filter :http_basic_authenticate, :only => :create, :if => Proc.new{|c| c.request.format == 'application/jsonrequest'}
  skip_before_filter :authenticate_user!, :verify_authenticity_token, :if => Proc.new{|c| c.request.format == 'application/jsonrequest'}

  autocomplete :pmdoc,  :sourceid, :class_name => :doc, :scopes => [:pmdocs,  :project_name => :project_name]
  autocomplete :pmcdoc, :sourceid, :class_name => :doc, :scopes => [:pmcdocs, :project_name => :project_name]
  autocomplete :user, :username
  autocomplete :project, :name, :full => true, :scopes => [:public_or_blind]
  autocomplete :project, :author

  # GET /projects
  # GET /projects.json
  def index
    respond_to do |format|
      format.html {
        @projects_grid = initialize_grid(Project.accessible(current_user),
          order: :status,
          include: :user
        )

        @projects_total_number = Project.accessible(current_user).length
      }
      format.json {
        projects = Project.accessible(current_user).order(:status)
        render json: projects
      }
    end
  end

  # GET /projects/:name
  # GET /projects/:name.json
  def show
    begin
      @project = Project.accessible(current_user).find_by_name(params[:id])
      raise "There is no such project." unless @project.present?

      # @sourcedbs = Doc.select(:sourcedb).uniq.pluck(:sourcedb).select{|s| Doc.sourcedb_public?(s) || Doc.sourcedb_mine?(s, current_user)}
      # @sourcedbs_active = @project.docs.select(:sourcedb).uniq.pluck(:sourcedb)
      # @sourcedbs = ['PubMed', 'PMC', 'FirstAuthor']
      # @sourcedbs_active = ['PubMed', 'PMC', 'FirstAuthor']
      @sourcedbs = ['PubMed', 'PMC']
      @sourcedbs_active = ['PubMed', 'PMC']

      respond_to do |format|
        format.html
        format.json {render json: @project.anonymize ? @project.as_json(except: [:maintainer]) : @project.as_json}
      end
    rescue => e
      respond_to do |format|
        format.html {redirect_to home_path, :notice => e.message}
        format.json {head :unprocessable_entity}
      end
    end
  end


  # GET /projects/new
  # GET /projects/new.json
  def new
    # set the dafault value for editor
    @project = Project.new
    @project.user = current_user

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @project }
    end
  end

  # POST /projects
  # POST /projects.json
  def create
    if params[:project].class == ActionDispatch::Http::UploadedFile
      params_from_json = Project.params_from_json(params[:project].tempfile)
      params[:project] = params_from_json
    end
    @project = Project.new(params[:project])
    @project.user = current_user
    respond_to do |format|
      if @project.save
        @project.build_associate_maintainers(params[:usernames])
        @project.save
        format.html { redirect_to project_path(@project.name), :notice => t('controllers.shared.successfully_created', :model => t('views.shared.annotation_sets')) }
        format.json { render json: @project, status: :created, location: @project }
      else
        format.html { render action: "new" }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /projects/1/edit
  def edit
    @project = Project.editable(current_user).find_by_name(params[:id])
  end

  # PUT /projects/:name
  # PUT /projects/:name.json
  def update
    @project.user = current_user unless current_user.root?
    respond_to do |format|
      if @project.update_attributes(params[:project])
        format.html { redirect_to project_path(@project.name), :notice => t('controllers.shared.successfully_updated', :model => t('views.shared.annotation_sets')) }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  def create_from_zip
    zip_file = params[:zip].path

    if zip_file.present? && params[:zip].content_type == 'application/zip'
      project_name = File.basename(params[:zip].original_filename, ".*")
      messages, errors = Project.create_from_zip(zip_file, project_name, current_user)
      # 結果をうけとってメッセージに表示
      if messages.present?
        flash[:notice] = messages.join('<br />')
      else errors.present?
        flash[:notice] = errors.join('<br />')
      end
    end
  end

  def obtain_annotations
    @project = Project.editable(current_user).find_by_name(params[:id])
    # @sourcedbs = ["PubMed", "PMC", "FirstAuthor"]
    @sourcedbs = ["PubMed", "PMC"]
  end

  def upload_annotations
    @project = Project.editable(current_user).find_by_name(params[:id])
  end

  def delete_annotations
    @project = Project.editable(current_user).find_by_name(params[:id])
  end

  def store_annotation_rdf
    begin
      raise RuntimeError, "Not authorized" unless current_user && current_user.root? == true

      projects = if params[:id].present?
        project = Project.find_by_name(params[:id])
        raise ArgumentError, "There is no such project." unless project.present?
        [project]
      else
        Project.for_index
      end

      system = Project.find_by_name('system-maintenance')

      projects.each do |project|
        delayed_job = Delayed::Job.enqueue StoreRdfizedAnnotationsJob.new(system, project, Pubann::Application.config.rdfizer_annotations), queue: :general
        Job.create({name:"Store RDFized annotations - #{project.name}", project_id:system.id, delayed_job_id:delayed_job.id})
      end
    rescue => e
      flash[:notice] = e.message
    end
    redirect_to project_path('system-maintenance')
  end

  def store_span_rdf
    begin
      raise RuntimeError, "Not authorized" unless current_user && current_user.root? == true
      project = Project.editable(current_user).find_by_name(params[:id])
      raise ArgumentError, "There is no such project." unless project.present?
      docids = project.docs.pluck(:id)
      system = Project.find_by_name('system-maintenance')

      delayed_job = Delayed::Job.enqueue StoreRdfizedSpansJob.new(system, docids, Pubann::Application.config.rdfizer_spans), queue: :general
      Job.create({name:"Store RDFized spans - #{project.name}", project_id:system.id, delayed_job_id:delayed_job.id})
    rescue => e
      flash[:notice] = e.message
    end
    redirect_to project_path('system-maintenance')
  end

  def clean
    begin
      raise RuntimeError, "Not authorized" unless current_user && current_user.root? == true

      projects = if params[:id].present?
        project = Project.find_by_name(params[:id])
        raise ArgumentError, "There is no such project." unless project.present?
        [project]
      else
        Project.all
      end

      system = Project.find_by_name('system-maintenance')

      projects.each do |project|
        project.clean
      end

      # projects.each do |project|
      #   delayed_job = Delayed::Job.enqueue StoreRdfizedAnnotationsJob.new(system, project.annotations_collection, Pubann::Application.config.rdfizer_annotations, project.name), queue: :general
      #   Job.create({name:"Store REDized annotations - #{project.name}", project_id:system.id, delayed_job_id:delayed_job.id})
      # end
    # rescue => e
    #   flash[:notice] = e.message
    end
    redirect_to project_path('system-maintenance')
  end

  def delete_all_docs
    begin
      project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "The project does not exist, or you are not authorized to make a change to the project.\n" unless project.present?

      message = if project.has_doc?
        # project.delete_docs
        # ActionController::Base.new.expire_fragment("sourcedb_counts_#{project.name}")
        # ActionController::Base.new.expire_fragment("count_docs_#{project.name}")
        # "All the documents in this project were deleted."

        priority = project.jobs.unfinished.count
        delayed_job = Delayed::Job.enqueue DeleteAllDocsFromProjectJob.new(project), priority: priority, queue: :general
        Job.create({name:'Delete all docs', project_id:project.id, delayed_job_id:delayed_job.id})
        "The task, 'delete all docs', is created."
      else
        "The project had no document. Nothing happened.\n"
      end

      respond_to do |format|
        format.html {redirect_to project_path(project.name), notice: message}
        format.json {render json:{message: message}}
        format.txt  {render text:message}
      end
    rescue => e
      respond_to do |format|
        format.html {redirect_to project_path(project.name), notice: e.message}
        format.json {render json:{message: e.message}, status: :unprocessable_entity}
        format.txt  {render text:e.message, status: :unprocessable_entity}
      end
    end
  end

  def destroy_all_annotations
    begin
      project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "The project does not exist, or you are not authorized to make a change to the project.\n" unless project.present?

      project.delete_annotations
      message = "Annotations in the project are all deleted.\n"

      respond_to do |format|
        format.html {redirect_to project_path(project.name), notice: message}
        format.json {render json:{message: message}}
        format.txt  {render text:message}
      end
    rescue => e
      respond_to do |format|
        format.html {redirect_to project_path(project.name), notice: e.message}
        format.json {render json:{message: e.message}, status: :unprocessable_entity}
        format.txt  {render text:e.message, status: :unprocessable_entity}
      end
    end
  end

  # DELETE /projects/:name
  # DELETE /projects/:name.json
  def destroy
    project = Project.editable(current_user).find_by_name(params[:id])
    raise "There is no such project." unless project.present?

    sproject = Project.find_by_name('system-maintenance')

    priority = project.jobs.unfinished.count
    delayed_job = Delayed::Job.enqueue DestroyProjectJob.new(project), priority: priority, queue: :general
    Job.create({name:'Destroy project', project_id:sproject.id, delayed_job_id:delayed_job.id})

    respond_to do |format|
      format.html {redirect_to projects_path, status: :see_other, notice: "The project, #{@project.name}, will be deleted soon."}
      format.json {head :no_content }
    end
  end

  def clear_finished_jobs
    project = Project.editable(current_user).find_by_name(params[:project_id])
    raise "There is no such project." unless project.present?

    project.jobs.finished.each do |job|
      job.destroy_if_not_running
    end

    respond_to do |format|
      format.html { redirect_to project_jobs_path(project.name) }
      format.json { head :no_content }
    end
  end
  
  def search
    @project, notice = get_project(params[:id])
    if @project
      docs = @project.docs
      # PubMed
      pmdocs = docs.where(:sourcedb => 'PubMed')
      if params[:doc] == 'PubMed'
        pmdocs = pmdocs.where('sourceid like ?', "%#{params[:sourceid]}%") if params[:sourceid].present?
        pmdocs = pmdocs.where('body like ?', "%#{params[:body]}%") if params[:body].present?
        @pm_sourceid_value = params[:sourceid]
        @pm_body_value = params[:body]
      end
      @pmdocs = pmdocs.page(params[:page])
      # PMC
      pmcdocs = docs.pmcdocs
      if params[:doc] == 'PMC'
        pmcdocs = pmcdocs.where('sourceid like ?', "%#{params[:sourceid]}%") if params[:sourceid].present?
        pmcdocs = pmcdocs.where('body like ?', "%#{params[:body]}%") if params[:body].present?
        @pmc_sourceid_value = params[:sourceid]
        @pmc_body_value = params[:body]
      end
      @pmcdocs = pmcdocs.page(params[:page])
      flash[:notice] = notice
      render :template => 'projects/show'
    end
  end

  def compare
    begin
      project = Project.editable(current_user).find_by_name(params[:id])
      raise "There is no such project in your management." unless project.present?

      project_ref = Project.find_by_name(params["select_project"])
      raise ArgumentError, "There is no such a project." if project_ref.nil?
      raise ArgumentError, "You cannot compare a project with itself" if project_ref == project

      docs = project.docs
      docs_ref = project_ref.docs
      docs_common = docs & docs_ref

      raise ArgumentError, "There is no shared document with the project, #{project_ref.name}" if docs_common.length == 0
      raise ArgumentError, "For a performance reason, current implementation limits this feature to work for less than 3,000 documents. (#{docs_common.length})" if docs_common.length > 3000

      # project.create_comparison(project_ref)

      priority = project.jobs.unfinished.count
      delayed_job = Delayed::Job.enqueue CompareAnnotationsJob.new(project, project_ref), priority: priority, queue: :general
      Job.create({name:'Compare annotations', project_id:project.id, delayed_job_id:delayed_job.id})
      message = "The task, 'compare annotations to the project, #{project_ref.name}', is created."

    rescue => e
      message = e.message
    end

    respond_to do |format|
      format.html {redirect_to project_path(project.name), notice: message}
      format.json {render json:{message:message}}
    end
  end

  def show_comparison
    @project = Project.editable(current_user).find_by_name(params[:id])
    raise "There is no such project in your management." unless @project.present?
    @comparison = JSON.parse(File.read(@project.comparison_path), symbolize_names: true)

    respond_to do |format|
      format.html
      format.json {render json:@comparison}
    end
  end

  def autocomplete_project_author
    render json: Project.where(['author like ?', "%#{params[:term]}%"]).collect{|project| project.author}.uniq
  end

  def autocomplete_sourcedb
    project = Project.accessible(current_user).find_by_name(params[:id])
    render :json => project.docs.where("sourcedb ILIKE ?", "%#{params[:term]}%").pluck(:sourcedb).uniq
  end

  def is_owner?
    render_status_error(:forbidden) unless @project.present? && @project.user == current_user
  end
  
  def updatable?
    case params[:action]
    when 'edit'
      @project = Project.find_by_name(params[:id])
    when 'update'
      @project = Project.find(params[:id])
      if current_user == @project.user
        # add associate maintainers
        @project.build_associate_maintainers(params[:usernames])
      end
    end
    unless @project.editable?(current_user)
      render_status_error(:forbidden)
    end
  end
  
  def destroyable?
    @project = Project.find_by_name(params[:id])
    unless @project.destroyable?(current_user)
      render_status_error(:forbidden)
    end  
  end
end
