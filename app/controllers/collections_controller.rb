class CollectionsController < ApplicationController
  before_filter :authenticate_user!, :except => [:index, :show]
  before_filter :set_collection, only: [:show, :edit, :update, :destroy]

  respond_to :html

  def index
    respond_to do |format|
      format.html {
        @collections_grid = initialize_grid(Collection.accessible(current_user),
          order: 'collections.updated_at',
          include: :user
        )
        @collections_total_number = Collection.count
      }
      format.json {
        collections = Collection.order(:updated_at)
        render json: collections
      }
    end
  end

  def show
    begin
      raise "There is no such collection." unless @collection.present?
      @projects_grid = initialize_grid(@collection.projects.accessible(current_user),
        order: 'projects.name',
        include: :user
      )

      respond_to do |format|
        format.html
        format.json {render json: @collection.as_json}
      end
    rescue => e
      respond_to do |format|
        format.html {redirect_to collections_path, :notice => e.message}
        format.json {head :unprocessable_entity}
      end
    end
  end

  def new
    @collection = Collection.new
    @collection.user = current_user
    respond_with(@collection)
  end

  def create
    @collection = Collection.new(params[:collection])
    @collection.user = current_user

    respond_to do |format|
      if @collection.save
        format.html { redirect_to collection_path(@collection.name), :notice => t('controllers.shared.successfully_created', :model => t('activerecord.models.collection')) }
        format.json { render json: @collection, status: :created, location: @collection }
      else
        format.html { render action: "new" }
        format.json { render json: @collection.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    @collection = Collection.find(params[:id])
    @collection.user = current_user unless current_user.root?
    respond_to do |format|
      if @collection.update_attributes(params[:collection])
        format.html { redirect_to collection_path(@collection.name), :notice => t('controllers.shared.successfully_updated', :model => t('activerecord.models.collection')) }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @collection.errors, status: :unprocessable_entity }
      end
    end
  end

  def add_project
    @collection = Collection.find_by_name(params[:collection_id])
    project_name = params[:select_project]
    project = Project.find_by_name(project_name)
    message = if project
      if @collection.projects.include?(project)
        "The project already exist in this collection: '#{project_name}'."
      else
        @collection.projects << project
        "The project added to this collection: '#{project_name}'."
      end
    else
      "Could not find the project: '#{project_name}'."
    end

    respond_to do |format|
      format.html {redirect_to :back, notice: message}
      format.json {render json:{message:message}}
    end
  end

  def remove_project
    @collection = Collection.find_by_name(params[:collection_id])
    project_name = params[:id]
    project = Project.find_by_name(project_name)
    message = if project
      if @collection.projects.delete(project)
        "The project removed from this collection: '#{project_name}'."
      else
        "This collection does not have the project: '#{project_name}'."
      end
    else
      "Could not find the project: '#{project_name}'."
    end

    respond_to do |format|
      format.html {redirect_to :back, notice: message}
      format.json {render json:{message:message}}
    end
  end

  def destroy
    @collection.destroy
    respond_with(@collection)
  end

  private
    def set_collection
      @collection = Collection.accessible(current_user).find_by_name(params[:id])
    end
end
