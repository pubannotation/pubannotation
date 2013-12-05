class DocumentationsController < ApplicationController
  before_filter :authenticate_user!, :except => [:index, :category, :show]
  before_filter :maintainable?, :except => [:index, :category, :show]

  def index
  end
  
  def category
    @documentation_category = DocumentationCategory.find_by_name(params[:name])
  end
  
  def show
    @documentation = Documentation.find(params[:id])
  end

  # admin only 
  
  def new
    @documentation = Documentation.new
  end
  
  def create
    @documentation = Documentation.new(params[:documentation])
    if @documentation.save!
      redirect_to @documentation
    else
      render :action => 'new'
    end
  end

  def edit
    @documentation = Documentation.find(params[:id])
  end

  def update
    @documentation = Documentation.find(params[:id])
    if @documentation.update_attributes(params[:documentation])
      redirect_to @documentation
    else
      render :action => 'edit'
    end
  end
  
  def destroy
    @documentation = Documentation.find(params[:id])
    @documentation.destroy
    redirect_to documentations_path    
  end
  
  # conditions who can create, update documentation
  def maintainable?
    Documentation.maintainable_for?(current_user)
  end 
end