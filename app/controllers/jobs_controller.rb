class JobsController < ApplicationController
	# GET /jobs
	# GET /jobs.json
	def index
		begin
			@organization = get_organization
			raise "Could not find the project or collection." unless @organization.present?
			@jobs = @organization.jobs.order(:created_at)

			respond_to do |format|
				format.html { redirect_to_organization if @jobs.empty? }
				format.json { render json: @jobs }
			end
		rescue
			respond_to do |format|
				format.html { redirect_to_organization }
				format.json { render status: :no_content }
			end
		end
	end

	# GET /jobs/1
	# GET /jobs/1.json
	def show
		@organization = get_organization
		raise "Could not find the project or collection." unless @organization.present?

		@job = Job.find(params[:id])
		raise "The project or collection does not have the job." unless @job.organization == @organization

		@messages_grid = initialize_grid(@job.messages,
			order: :created_at,
			per_page: 10
		)

		respond_to do |format|
			format.html # show.html.erb
			format.json { render json: @job }
		end
	end

	# GET /jobs/new
	# GET /jobs/new.json
	def new
		@job = Job.new

		respond_to do |format|
			format.html # new.html.erb
			format.json { render json: @job }
		end
	end

	# GET /jobs/1/edit
	def edit
		@job = Job.find(params[:id])
	end

	# POST /jobs
	# POST /jobs.json
	def create
		@job = Job.new(params[:job])

		respond_to do |format|
			if @job.save
				format.html { redirect_to @job, notice: 'Job was successfully created.' }
				format.json { render json: @job, status: :created, location: @job }
			else
				format.html { render action: "new" }
				format.json { render json: @job.errors, status: :unprocessable_entity }
			end
		end
	end

	# PUT /jobs/1
	# PUT /jobs/1.json
	def update
		organization = get_organization
		raise "Could not find the project or collection." unless organization.present? && organization.editable?(current_user)

		job = Job.find(params[:id])
		raise "The project or collection does not have the job." unless job.organization == organization

		job.stop_if_running

		respond_to do |format|
			format.html { redirect_to :back }
		end
	end

	# DELETE /jobs/1
	# DELETE /jobs/1.json
	def destroy
		organization = get_organization
		raise "Could not find the project or collection." unless organization.present? && organization.editable?(current_user)

		job = Job.find(params[:id])
		raise "The project or collection does not have the job." unless job.organization == organization

		job.destroy_if_not_running

		respond_to do |format|
			format.html { redirect_to_organization }
		end
	end

	private

	def get_organization
		if params.has_key? :project_id
			Project.accessible(current_user).find_by_name(params[:project_id])
		elsif params.has_key? :collection_id
			Collection.accessible(current_user).find_by_name(params[:collection_id])
		end
	end

	def redirect_to_organization
		if params.has_key? :project_id
			redirect_to project_path(params[:project_id])
		elsif params.has_key? :collection_id
			redirect_to collection_path(params[:collection_id])
		end
	end

end
