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
  autocomplete :project, :name, :full => true, :scopes => [:id_in => :project_ids]
  autocomplete :project, :author

  # GET /projects
  # GET /projects.json
  def index
    sort_order = sort_order(Project)
    sourcedb, sourceid, serial, id = get_docspec(params)
    if sourcedb
      @doc = Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, serial)
      if @doc
        @projects = @doc.projects.accessible(current_user).sort_by_params(sort_order)
        @projects = @doc.projects.accessible(current_user).sort_by_params(sort_order)
      else
        @projects = nil
        notice = t('controllers.projects.index.does_not_exist', :sourcedb => sourcedb, :sourceid => sourceid)
      end
    else
      if params[:search_projects]
        conditions_array = Array.new
        conditions_array << ['name like ?', "%#{params[:name]}%"] if params[:name].present?
        conditions_array << ['description like ?', "%#{params[:description]}%"] if params[:description].present?
        conditions_array << ['author like ?', "%#{params[:author]}%"] if params[:author].present?
        conditions_array << ['users.username like ?', "%#{params[:user]}%"] if params[:user].present?
        
        # Build condition
        i = 0
        conditions = Array.new
        columns = ''
        conditions_array.each do |key, val|
          key = " AND #{key}" if i > 0
          columns += key
          conditions[i] = val
          i += 1
        end
        conditions.unshift(columns)
        @projects = Project.accessible(current_user).includes(:user).where(conditions).group('projects.id').sort_by_params(sort_order).paginate(:page => params[:page])
        flash[:notice] = t('controllers.projects.index.not_found') if @projects.blank?
      else
        @projects = Project.accessible(current_user).sort_by_params(sort_order).paginate(:page => params[:page])
      end
    end

    respond_to do |format|
      format.html {
        if @doc and @projects.blank?
          redirect_to home_path, :notice => notice
        end
      }
      format.json { render json: @projects }
    end
  end


  # GET /projects/:name
  # GET /projects/:name.json
  def show
    begin
      @project = Project.accessible(current_user).find_by_name(params[:id])
      raise "There is no such project." unless @project.present?

      @docs = @project.docs.where(serial: 0)
      @search_path = search_project_docs_path(@project.name)

      @annotators = Annotator.all
      @annotator_options = @annotators.map{|a| [a[:abbrev], a[:abbrev]]}

      respond_to do |format|
        format.html
        format.json {render json: @project.json} 
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
    @project = Project.new({editor: Project::EditorDefault})
    @project.user = current_user

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @project }
    end
  end

  # GET /projects/1/edit
  def edit
    @project = Project.editable(current_user).find_by_name(params[:id])
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
        @project.add_associate_projects(params[:associate_projects], current_user)
        format.html { redirect_to project_path(@project.name), :notice => t('controllers.shared.successfully_created', :model => t('views.shared.annotation_sets')) }
        format.json { render json: @project, status: :created, location: @project }
      else
        format.html { render action: "new" }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  def zip_upload
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

  # PUT /projects/:name
  # PUT /projects/:name.json
  def update
    respond_to do |format|
      if @project.update_attributes(params[:project])
        @project.add_associate_projects(params[:associate_projects], current_user)
        format.html { redirect_to project_path(@project.name), :notice => t('controllers.shared.successfully_updated', :model => t('views.shared.annotation_sets')) }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  def index_project_annotations_rdf
    begin
      raise RuntimeError, "Not authorized" unless current_user && current_user.root? == true
      project = Project.find_by_name(params[:id])
      raise ArgumentError, "There is no such project." unless project.present?

      system = Project.find_by_name('system-maintenance')
      system.notices.create({method: "index project annotations rdf: #{project.name}"})
      system.delay.index_project_annotations_rdf(project)
    rescue => e
      flash[:notice] = e.message
    end
    redirect_to project_path('system-maintenance')
  end

  def index_annotations_rdf
    begin
      raise RuntimeError, "Not authorized" unless current_user && current_user.root? == true
      system = Project.find_by_name('system-maintenance')
      system.notices.create({method: "index annotations rdf"})
      system.delay.index_annotations_rdf
    rescue => e
      flash[:notice] = e.message
    end
    redirect_to project_path('system-maintenance')
  end

  def destroy_annotations
    begin
      @project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "There is no such project in your management." unless @project.present?

      @project.notices.create({method: 'delete all the annotations in the project'})
      @project.delay.destroy_annotations

      respond_to do |format|
        format.html {redirect_to project_path(@project.name), status: :see_other, notice: "The task, 'delete all the annotations in the project', is created."}
        format.json {render status: :no_content}
      end
    end
  end


  # DELETE /projects/:name
  # DELETE /projects/:name.json
  def destroy
    @project.notices.create({method: 'destroy the project'})
    @project.delay.delay_destroy
    respond_to do |format|
      format.html {redirect_to projects_path, status: :see_other, notice: "The project, #{@project.name}, is being deleted."}
      format.json {head :no_content }
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
      @pmdocs = pmdocs.paginate(:page => params[:page])
      # PMC
      pmcdocs = docs.pmcdocs
      if params[:doc] == 'PMC'
        pmcdocs = pmcdocs.where('sourceid like ?', "%#{params[:sourceid]}%") if params[:sourceid].present?
        pmcdocs = pmcdocs.where('body like ?', "%#{params[:body]}%") if params[:body].present?
        @pmc_sourceid_value = params[:sourceid]
        @pmc_body_value = params[:body]
      end
      @pmcdocs = pmcdocs.paginate(:page => params[:page])
      flash[:notice] = notice
      render :template => 'projects/show'
    end
  end

  def autocomplete_project_author
    render json: Project.where(['author like ?', "%#{params[:term]}%"]).collect{|project| project.author}.uniq
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
