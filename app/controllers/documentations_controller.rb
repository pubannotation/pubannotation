class DocumentationsController < ApplicationController
  def index
    @documentations = Documentation.all
  end

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
  
  def show
    @documentation = Documentation.find(params[:id])
  end

  def edit
    @documentation = Documentation.find(params[:id])
  end

  def update
    @documentation = Documentation.find(params[:id])
  end
end