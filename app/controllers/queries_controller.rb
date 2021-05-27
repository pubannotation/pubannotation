class QueriesController < ApplicationController
	before_filter :set_query, only: [:show, :edit, :update, :destroy]
	before_filter :set_project

	respond_to :html

	def index
		@queries = Query.where(project_id: @project)
		@queries_grid = if root_user?
			initialize_grid(Query,
				order: :category,
				order_direction: 'asc',
				include: :project
			)
		elsif @project
			initialize_grid(Query.where(project_id: @project.id),
				order: :category,
				order_direction: 'asc',
				include: :project
			)
		else
			initialize_grid(Query.where(category: 0),
				include: :project
			)
		end

		respond_with(@queries)
	end

	def show
		respond_to do |format|
			format.html {}
			format.json { render json: @query }
		end
	end

	def new
		@query = if params[:project_id]
			@project = Project.accessible(current_user).find_by_name(params[:project_id])
			raise "Could not find the project." unless @project.present?
			@project.queries.new
		else
			Query.new
		end
		respond_with(@query)
	end

	def edit
	end

	def create
		query = Query.new(query_params)
		respond_to do |format|
			if query.save
				format.html { redirect_to query.project ? project_query_path(query.project.name, query) : query_path(query) }
				format.json { render json: query, status: :created, location: query_path(query) }
			else
				format.html { render action: "new" }
				format.json { render json: query.errors, status: :unprocessable_entity }
			end
		end
	end

	def update
		@query.update_attributes(query_params)
		respond_to do |format|
			format.html { redirect_to @query.project ? project_query_path(@query.project.name, @query) : query_path(@query) }
			format.json { render json: query, status: :created, location: query_path(@query) }
		end
	end

	def destroy
		respond_to do |format|
			if @query.destroy
				format.html { redirect_to @query.project ? project_queries_path(@project.name) : queries_path }
			else
				format.html { redirect_to @query.project ? project_query_path(@query.project.name, @query) : query_path(@query) }
				format.json { render json: @query.errors, status: :unprocessable_entity }
			end
		end
	end

	private
		def set_project
			@project = if params.has_key? :project_id
				p = Project.accessible(current_user).find_by_name(params[:project_id])
				raise "Could not find the project: #{params[:project_id]}." unless p.present?
				p
			end
		end

		def set_query
			@query = Query.find(params[:id])
		end

		def query_params
			params.require(:query).permit(:active, :comment, :priority, :sparql, :reasoning,
																		:title, :project_id, :show_mode, :projects, :category)
		end
end
