class JobsController < ApplicationController
	before_action :authenticate_user!, :except => [:index, :show]
	before_action :set_organization, only: [:index, :show, :latest_jobs_table, :latest_gear_icon]
	before_action :set_editable_organization, only: [:update, :destroy, :clear_finished_jobs]

	# GET /jobs
	# GET /jobs.json
	def index
		Job.reap_zombies
		@jobs = @organization&.jobs.order(:created_at)

		respond_to do |format|
			format.html { redirect_to organization_path if @jobs.nil? || @jobs.empty? }
			format.json { render json: @jobs }
		end
	rescue => e
		respond_to do |format|
			format.html { redirect_to organization_path, fallback_location: root_path, notice: e.message }
			format.json { render status: :no_content }
		end
	end

	# GET /jobs/1
	# GET /jobs/1.json
	def show
		@job = Job.find(params.permit(:id)[:id])
		raise "Could not find the job." unless @job.organization == @organization

		@messages_grid = initialize_grid(@job.messages,
			order: :created_at,
			order_direction: :desc,
			per_page: 10
		)

		respond_to do |format|
			format.html # show.html.erb
			format.json { render json: @job }
		end
	rescue => e
		respond_to do |format|
			format.html { redirect_to organization_jobs_path, fallback_location: root_path, notice: e.message }
			format.json { render status: :no_content }
		end
	end

	# PUT /jobs/1
	# PUT /jobs/1.json
	def update
		job = Job.find(params[:id])
		raise "Could not find the job." unless job.organization == @organization

		job.stop_if_running

		respond_to do |format|
			format.html { redirect_back fallback_location: root_path }
		end
	end

	# DELETE /jobs/1
	# DELETE /jobs/1.json
	def destroy
		job = Job.find(params[:id])
		raise "Could not find the job." unless job.organization == @organization

		job.destroy_unless_running

		respond_to do |format|
			format.html { redirect_to organization_jobs_path }
		end
	end

	def clear_finished_jobs
		Job.batch_destroy_finished(@organization)

		respond_to do |format|
			format.html { redirect_to organization_jobs_path }
			format.json { head :no_content }
		end
	end

	def latest_jobs_table
		@jobs = @organization.jobs.order(:created_at)
		render :partial => "jobs/jobs_table", locals: {jobs: @jobs }
	end

	def latest_gear_icon
		if params.has_key? :project_id
			@project = @organization
			render :partial => 'projects/gear_icon'
		else
			@collection = @organization
			render :partial => 'collections/gear_icon'
		end
	end

	private

	def set_organization
		@organization = if params.has_key? :project_id
			Project.accessible(current_user).find_by_name(params[:project_id])
		elsif params.has_key? :collection_id
			Collection.accessible(current_user).find_by_name(params[:collection_id])
		else
			nil
		end
	end

	def set_editable_organization
		@organization = if params.has_key? :project_id
			Project.editable(current_user).find_by_name(params[:project_id])
		elsif params.has_key? :collection_id
			Collection.editable(current_user).find_by_name(params[:collection_id])
		else
			nil
		end
	end

	def organization_path
		if params.has_key? :project_id
			project_path(params[:project_id])
		elsif params.has_key? :collection_id
			collection_path(params[:collection_id])
		end
	end

	def organization_jobs_path
		if params.has_key? :project_id
			project_jobs_path(params[:project_id])
		elsif params.has_key? :collection_id
			collection_jobs_path(params[:collection_id])
		end
	end
end
