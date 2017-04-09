class EditorsController < ApplicationController
  before_filter :authenticate_user!, :only => [:new, :edit, :destroy]

  respond_to :html

  def index
    @editors = Editor.all
    @editors_grid = initialize_grid(Editor.accessibles(current_user),
      order: :name,
      include: :user
    )
    respond_with(@editors)
  end

  def show
    @editor = Editor.find(params[:id])
    @editor.parameters = @editor.parameters.map{|p| p.join(' = ')}.join("\n")
    respond_with(@editor)
  end

  def new
    @editor = Editor.new
    respond_with(@editor)
  end

  def edit
    @editor = Editor.find(params[:id])
    @editor.parameters = @editor.parameters.map{|p| p.join(' = ')}.join("\n")
  end

  def create
    @editor = Editor.new(params[:editor])
    @editor.user = current_user
    @editor.parameters = @editor.parameters.delete(' ').split(/[\n\r\t]+/).map{|p| p.split(/[:=]/)}.to_h if @editor.parameters.present?
    @editor.save
    respond_with(@editor)
  end

  def update
    @editor = Editor.find(params[:id])
    update = params[:editor]
    update['parameters'] = update['parameters'].delete(' ').split(/[\n\r\t]+/).map{|p| p.split(/[:=]/)}.to_h if update['parameters'].present?

    @editor.update_attributes(update)
    @editor.name = update['name']
    respond_with(@editor)
  end

  def destroy
    @editor = Editor.find(params[:id])
    @editor.destroy
    respond_with(@editor)
  end

end
