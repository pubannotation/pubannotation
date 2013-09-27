class SprojectsController < ApplicationController
  before_filter :authenticate_user!, :except => [:index, :show, :autocomplete_pmcdoc_sourceid, :autocomplete_pmdoc_sourceid, :search]
  autocomplete :pmdoc,  :sourceid, :class_name => :doc, :scopes => [:pmdocs,  :projects_docs => :project_name]
  autocomplete :pmcdoc, :sourceid, :class_name => :doc, :scopes => [:pmcdocs, :projects_docs => :project_name]
 
  def index
    @sprojects = Sproject.order_by(Sproject, params[:projects_order], current_user)
  end
  
  def new
    @sproject = Sproject.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @sproject }
    end
  end
  
  def create
    @sproject = current_user.sprojects.build(params[:sproject])
    respond_to do |format|
      if @sproject.save
        if params[:project_names].present?
          @projects = Project.where('name IN (?)', params[:project_names])
          @sproject.projects << @projects
        end        
        format.html { 
          redirect_to sproject_path(@sproject.name), 
          :notice => t('controllers.shared.successfully_created', 
          :model => t('activerecord.models.sproject')) }
        format.json { render json: @sproject, status: :created, location: @sproject }
      else
        format.html { render action: "new" }
        format.json { render json: @sproject.errors, status: :unprocessable_entity }
      end
    end    
  end
  
  def show
    @sproject, notice = get_sproject(params[:id])
    if @sproject.present?
      @pmdocs = Doc.order_by(@sproject.pmdocs, params[:docs_order]).paginate(:page => params[:page])
      @pmcdocs = Doc.order_by(@sproject.pmcdocs, params[:docs_order]).paginate(:page => params[:page])
    end
    respond_to do |format|
      if @sproject
        format.html { flash[:notice] = notice }
        format.json { render json: @sproject }
      else
        format.html {
          redirect_to home_path, :notice => notice
        }
        format.json { head :unprocessable_entity }
      end
    end
  end
  
  def edit
    @sproject = Sproject.where('name = ?', params[:id]).first
    @projects_sprojects = @sproject.projects_sprojects
  end
  
  def update
    @sproject = Sproject.find(params[:id])
    if params[:project_names].present?
      @projects = Project.where('name IN (?)', params[:project_names])
      @sproject.projects << @projects
    end
    
    respond_to do |format|
      if @sproject.update_attributes(params[:sproject])
        format.html { redirect_to sproject_path(@sproject.name), :notice => t('controllers.shared.successfully_updated', :model => t('views.shared.annotation_sets')) }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @sproject.errors, status: :unprocessable_entity }
      end
    end    
  end
  
  def destroy
    @sproject = Sproject.find_by_name(params[:id])
    @sproject.destroy

    respond_to do |format|
      format.html { redirect_to sprojects_path, notice: t('controllers.projects.destroy.deleted', :id => params[:id]) }
      format.json { head :no_content }
    end    
  end
  
  def search
    @sproject, notice = get_sproject(params[:id])
    if @sproject
      # PubMed
      pmdocs = @sproject.pmdocs
      if params[:doc] == 'PubMed'
        pmdocs = pmdocs.where('sourceid like ?', "%#{params[:sourceid]}%") if params[:sourceid].present?
        pmdocs = pmdocs.where('body like ?', "%#{params[:body]}%") if params[:body].present?
        @pm_sourceid_value = params[:sourceid]
        @pm_body_value = params[:body]
      end
      @pmdocs = pmdocs.paginate(:page => params[:page])
      # PMC
      pmcdocs = @sproject.pmcdocs
      if params[:doc] == 'PMC'
        pmcdocs = pmcdocs.where('sourceid like ?', "%#{params[:sourceid]}%") if params[:sourceid].present?
        pmcdocs = pmcdocs.where('body like ?', "%#{params[:body]}%") if params[:body].present?
        @pmc_sourceid_value = params[:sourceid]
        @pmc_body_value = params[:body]
      end
      @pmcdocs = pmcdocs.paginate(:page => params[:page])
      flash[:notice] = notice
      render :template => 'sprojects/show'
    end
  end  
end