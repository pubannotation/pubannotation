class EditorsController < ApplicationController
  before_filter :changeable?, :only => [:edit, :update, :destroy]
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
    begin
      begin
        @editor = Editor.accessibles(current_user).find(params[:id])
      rescue
        raise "Could not find the editor, #{params[:id]}."
      end

      @editor.parameters = @editor.parameters.map{|p| p.join(' = ')}.join("\n")
      respond_with(@editor)
    rescue => e
      redirect_to editors_path, :notice => e.message
    end
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

  def changeable?
    @editor = Editor.find(params[:id])
    render_status_error(:forbidden) unless @editor.changeable?(current_user)
  end
end
