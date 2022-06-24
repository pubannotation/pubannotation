class QueriesController < ApplicationController
	before_action :set_query, only: [:show, :edit, :update, :destroy]
	before_action :set_organization, only: [:index, :show]
	before_action :set_editable_organization, only: [:new, :create, :edit, :update, :destroy]

	respond_to :html

	def index
		@queries = if @organization
			@organization.queries
		else
			Query.all
		end

		@queries_grid = if root_user?
			initialize_grid(Query,
				order: :category,
				order_direction: 'asc'
			)
		elsif @organization
			initialize_grid(@organization.queries,
				order: :category,
				order_direction: 'asc'
			)
		else
			initialize_grid(Query.where(category: 0))
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
		@query = if @organization
			@organization.queries.new
		else
			Query.new
		end

		respond_with(@query)
	end

	def create
		query = Query.new(query_params)

		respond_to do |format|
			if query.save
				format.html { redirect_to redirect_query_path(query) }
				format.json { render json: query, status: :created, location: query_path(query) }
			else
				format.html { render action: "new" }
				format.json { render json: query.errors, status: :unprocessable_entity }
			end
		end
	end

	def edit
	end

	def update
		@query.update(query_params)
		respond_to do |format|
			format.html { redirect_to redirect_query_path(@query) }
			format.json { render json: query, status: :created, location: query_path(@query) }
		end
	end

	def destroy
		organization = @query.organization
		respond_to do |format|
			if @query.destroy
				format.html { redirect_to redirect_queries_path(organization) }
			else
				format.html { redirect_to redirect_query_path(query) }
				format.json { render json: @query.errors, status: :unprocessable_entity }
			end
		end
	end

	private

	def set_organization
		if params[:project_id].present?
			@organization = Project.accessible(current_user).find_by_name(params[:project_id])
			raise "Could not find the project." unless @organization.present?
		elsif params[:collection_id].present?
			@organization = Collection.accessible(current_user).find_by_name(params[:collection_id])
			raise "Could not find the collection." unless @organization.present?
		else
			@organization = nil
		end
	end

	def set_editable_organization
		if params[:project_id].present?
			@organization = Project.editable(current_user).find_by_name(params[:project_id])
			raise "Could not find the project." unless @organization.present?
		elsif params[:collection_id].present?
			@organization = Collection.editable(current_user).find_by_name(params[:collection_id])
			raise "Could not find the collection." unless @organization.present?
		else
			@organization = nil
		end
	end

	def redirect_query_path(query)
		if query.organization
			if query.organization_type == 'Project'
				project_query_path(query.organization.name, query.id)
			else
				collection_query_path(query.organization.name, query.id)
			end
		else
			query_path(query.id)
		end
	end

	def redirect_queries_path(organization)
		if organization
			if organization.class == Project
				project_queries_path(organization.name)
			else
				collection_queries_path(organization.name)
			end
		else
			queries_path
		end
	end

	def set_query
		@query = Query.find(params[:id])
	end

	def query_params
		params.require(:query).permit(:active, :comment, :priority, :sparql, :reasoning,
																	:title, :organization_id, :organization_type, :show_mode, :projects, :category)
	end
end
