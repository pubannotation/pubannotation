class EditorsController < ApplicationController
	include IniFileConvertible
	before_action :changeable?, :only => [:edit, :update, :destroy]
	before_action :authenticate_user!, :only => [:new, :edit, :destroy]

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
	end

	def create
		params = editor_params
		params[:user] = current_user
		params[:parameters] = convert_str_to_hash(params[:parameters])
		@editor = Editor.create(params)
		respond_with(@editor)
	end

	def update
		@editor = Editor.find(params[:id])
		params = editor_params
		params[:parameters] = convert_str_to_hash(params[:parameters])

		@editor.update_attributes(params)
		@editor.name = params[:name]
		respond_with(@editor)
	end

	def destroy
		@editor = Editor.find(params[:id])
		@editor.destroy
		respond_with(@editor)
	end

	private

	def editor_params
		params.require(:editor).permit(:description, :home, :is_public, :name, :parameters, :url)
	end

	def changeable?
		@editor = Editor.find(params[:id])
		render_status_error(:forbidden) unless @editor.changeable?(current_user)
	end
end
