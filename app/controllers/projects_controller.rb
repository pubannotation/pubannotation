class ProjectsController < ApplicationController
  before_filter :authenticate_user!, :except => [:index, :show, :autocomplete_pmcdoc_sourceid, :autocomplete_pmdoc_sourceid, :search]
  before_filter :updatable?, :only => [:edit, :update]
  before_filter :destroyable?, :only => :destroy
  before_filter :authenticate_user!, :except => [:index, :show, :autocomplete_pmcdoc_sourceid, :autocomplete_pmdoc_sourceid, :search]
  autocomplete :pmdoc,  :sourceid, :class_name => :doc, :scopes => [:pmdocs,  :project_name => :project_name]
  autocomplete :pmcdoc, :sourceid, :class_name => :doc, :scopes => [:pmcdocs, :project_name => :project_name]
  autocomplete :user, :username
  autocomplete :project, :name, :full => true, :scopes => [:id_in => :project_ids]

  # GET /projects
  # GET /projects.json
  def index
    sourcedb, sourceid, serial = get_docspec(params)
    if sourcedb
      @doc = Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, serial)
      if @doc
        @projects = Project.order_by(@doc.projects, params[:projects_order], current_user)
      else
        @projects = nil
        notice = t('controllers.projects.index.does_not_exist', :sourcedb => sourcedb, :sourceid => sourceid)
      end
    else
      @projects = Project.order_by(Project, params[:projects_order], current_user)
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
    @project, notice = get_project(params[:id])
    if @project
      sourcedb, sourceid, serial = get_docspec(params)
      if sourceid
        @doc, notice = get_doc(sourcedb, sourceid, serial, @project)
      else
        docs = @project.docs
        @pmdocs = Doc.order_by(docs.pmdocs, params[:docs_order]).paginate(:page => params[:page])
        @pmcdocs = Doc.order_by(docs.pmcdocs, params[:docs_order]).paginate(:page => params[:page])
        # @pmcdocs = docs.select{|d| d.sourcedb == 'PMC' and d.serial == 0}
        if params[:accordion_id].blank?
          if @pmdocs.size != @pmcdocs.size
            if @pmdocs.size > @pmcdocs.size
              @accordion_id = '1'
            else
              @accordion_id = '2'
            end
          end
        end
      end
      if params[:accordion_id].present?
        @accordion_id = params[:accordion_id]
      end
    end

    respond_to do |format|
      if @project
        format.html { flash[:notice] = notice }
        format.json { render json: @project }
      else
        format.html {
          redirect_to home_path, :notice => notice
        }
        format.json { head :unprocessable_entity }
      end
    end
  end


  # GET /projects/new
  # GET /projects/new.json
  def new
    @project = Project.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @project }
    end
  end

  # GET /projects/1/edit
  def edit
    @sourcedb, @sourceid, @serial = get_docspec(params)
  end

  # POST /projects
  # POST /projects.json
  def create
    @project = Project.new(params[:project])
    @project.user = current_user
    respond_to do |format|
      if @project.save
        @project.add_associate_projects(params[:associate_projects])
        format.html { redirect_to project_path(@project.name), :notice => t('controllers.shared.successfully_created', :model => t('views.shared.annotation_sets')) }
        format.json { render json: @project, status: :created, location: @project }
      else
        format.html { render action: "new" }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /projects/:name
  # PUT /projects/:name.json
  def update
    respond_to do |format|
      if @project.update_attributes(params[:project])
        @project.add_associate_projects(params[:associate_projects])
        format.html { redirect_to project_path(@project.name), :notice => t('controllers.shared.successfully_updated', :model => t('views.shared.annotation_sets')) }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /projects/:name
  # DELETE /projects/:name.json
  def destroy
    @project.destroy

    respond_to do |format|
      format.html { redirect_to projects_path, notice: t('controllers.projects.destroy.deleted', :id => params[:id]) }
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
    unless @project.updatable_for?(current_user)
      render_status_error(:forbidden)
    end
  end
  
  def destroyable?
    @project = Project.find_by_name(params[:id])
    unless @project.destroyable_for?(current_user)
      render_status_error(:forbidden)
    end  
  end
end
