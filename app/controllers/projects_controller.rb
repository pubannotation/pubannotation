class ProjectsController < ApplicationController
	before_filter :updatable?, :only => [:edit, :update]
	before_filter :destroyable?, :only => :destroy
	before_filter :authenticate_user!, :except => [:index, :show, :autocomplete_pmcdoc_sourceid, :autocomplete_pmdoc_sourceid, :autocomplete_project_author, :search]
	# JSON POST
	before_filter :http_basic_authenticate, :only => :create, :if => Proc.new{|c| c.request.format == 'application/jsonrequest'}
	skip_before_filter :authenticate_user!, :verify_authenticity_token, :if => Proc.new{|c| c.request.format == 'application/jsonrequest'}

	autocomplete :user, :username
	autocomplete :project, :name, :full => true, :scopes => [:public_or_blind]
	autocomplete :project, :author

	# GET /projects
	# GET /projects.json
	def index
		respond_to do |format|
			format.html {
				@projects_grid = initialize_grid(Project.accessible(current_user),
					order: 'projects.status',
					custom_order: {
						'projects.status' => 'projects.status, projects.updated_at'
					},
					include: :user
				)
				@projects_total_number = Project.accessible(current_user).count
			}
			format.json {
				projects = Project.accessible(current_user).order(:status)
				render json: projects
			}
		end
	end

	# GET /projects/:name
	# GET /projects/:name.json
	def show
		begin
			@project = Project.accessible(current_user).find_by_name(params[:id])
			raise "There is no such project." unless @project.present?

			respond_to do |format|
				format.html
				format.json {render json: @project.anonymize ? @project.as_json(except: [:maintainer]) : @project.as_json}
			end
		rescue => e
			respond_to do |format|
				format.html {redirect_to home_path, :notice => e.message}
				format.json {head :unprocessable_entity}
			end
		end
	end


	# GET /projects/new
	# GET /projects/new.json
	def new
		# set the dafault value for editor
		@project = Project.new
		@project.user = current_user

		@collection = if params[:collection_id].present?
			collection = Collection.addable(current_user).find_by_name(params[:collection_id])
			raise "Could not find the collection: #{params[:collection_id]}" unless collection.present?
			collection
		end

		respond_to do |format|
			format.html # new.html.erb
			format.json { render json: @project }
		end
	end

	# POST /projects
	# POST /projects.json
	def create
		if params[:project].class == ActionDispatch::Http::UploadedFile
			params_from_json = Project.params_from_json(params[:project].tempfile)
			params[:project] = params_from_json
		end

		@project = Project.new(params[:project])
		@project.user = current_user

		@collection = if params[:collection_id].present?
			collection = Collection.addable(current_user).find_by_name(params[:collection_id])
			raise "Could not find the collection: #{params[:collection_id]}" unless collection.present?
			collection
		end

		respond_to do |format|
			if @project.save
				@collection.projects << @project if @collection.present?
				format.html { redirect_to project_path(@project.name), :notice => t('controllers.shared.successfully_created', :model => t('views.shared.annotation_sets')) }
				format.json { render json: @project, status: :created, location: @project }
			else
				format.html { render action: "new" }
				format.json { render json: @project.errors, status: :unprocessable_entity }
			end
		end
	end

	# GET /projects/1/edit
	def edit
		@project = Project.editable(current_user).find_by_name(params[:id])
	end

	# PUT /projects/:name
	# PUT /projects/:name.json
	def update
		@project.user = current_user unless current_user.root?
		respond_to do |format|
			if @project.update_attributes(params[:project])
				format.html { redirect_to project_path(@project.name), :notice => t('controllers.shared.successfully_updated', :model => t('views.shared.annotation_sets')) }
				format.json { head :no_content }
			else
				format.html { render action: "edit" }
				format.json { render json: @project.errors, status: :unprocessable_entity }
			end
		end
	end

	def add_docs
		@project = Project.editable(current_user).find_by_name(params[:id])
	end

	def upload_docs
		@project = Project.editable(current_user).find_by_name(params[:id])
	end

	def uptodate_docs
		begin
			project = Project.find_by_name(params[:id])
			raise RuntimeError, "Not authorized" unless current_user && current_user.root? == true

			# job = UptodateDocsJob.new(project)
			# job.perform()

			delayed_job = Delayed::Job.enqueue UptodateDocsJob.new(project), queue: :general
			task_name = "Uptodate docs in project - #{project.name}"
			Job.create({name:task_name, project_id:project.id, delayed_job_id:delayed_job.id})
			flash[:notice] = "The task, '#{task_name}', is created."
			redirect_to project_path(project.name)
		rescue => e
			flash[:notice] = e.message
			redirect_to project_path(project.name)
		end
	end

	def obtain_annotations
		@project = Project.editable(current_user).find_by_name(params[:id])
	end

	def rdfize_annotations
		@project = Project.editable(current_user).find_by_name(params[:id])
	end

	def upload_annotations
		@project = Project.editable(current_user).find_by_name(params[:id])
	end

	def delete_annotations
		@project = Project.editable(current_user).find_by_name(params[:id])
	end

	def store_annotation_rdf
		begin
			project = Project.editable(current_user).find_by_name(params[:id])
			raise ArgumentError, "Could not find the project: #{params[id]}." unless project.present?
			raise "Up to 10 jobs can be registered per a project. Please clean your jobs page." unless project.jobs.count < 10

			sourceids = if params[:upfile].present?
				File.readlines(params[:upfile].path)
			elsif params[:ids].present?
				params[:ids].split(/[ ,"':|\t\n\r]+/).map{|id| id.strip.sub(/^(PMC|pmc)/, '')}.uniq
			else
				[] # means all the docs in the project
			end
			sourceids.map{|id| id.chomp!}

			raise ArgumentError, "Source DB is not specified." if sourceids.present? && !params['sourcedb'].present?

			sourcedb = params['sourcedb']

			docids = if sourceids.empty?
				project.docs.pluck(:doc_id)
			else
				sourceids.inject([]) do |col, sourceid|
					ids = project.docs.where(sourcedb:sourcedb, sourceid:sourceid).pluck(:id)
					raise ArgumentError, "#{sourcedb}:#{sourceid} does not exist in this project." if ids.empty?
					col += ids
				end
			end

			filepath = File.join('tmp', "store_rdf-#{project.name}-#{Time.now.to_s[0..18].gsub(/[ :]/, '-')}.txt")
			File.open(filepath, "w"){|f| f.puts(docids)}
			filepath

			# job = StoreRdfizedAnnotationsJob.new(project, filepath)
			# job.perform()

			delayed_job = Delayed::Job.enqueue StoreRdfizedAnnotationsJob.new(project, filepath), queue: :general
			Job.create({name:"Store RDFized annotations - #{project.name}", project_id:project.id, delayed_job_id:delayed_job.id})
			flash[:notice] = "The task, 'Store RDFized annotations - #{project.name}', is created."
		rescue => e
			flash[:notice] = e.message
		end
		redirect_to project_path(project.name)
	end

	def store_annotation_rdf_all
		begin
			raise RuntimeError, "Not authorized" unless current_user && current_user.root? == true

			projects = if params[:id].present?
				project = Project.find_by_name(params[:id])
				raise ArgumentError, "There is no such project." unless project.present?
				[project]
			else
				Project.for_index
			end

			system = Project.find_by_name('system-maintenance')

			projects.each do |project|
				delayed_job = Delayed::Job.enqueue StoreRdfizedAnnotationsJob.new(system, project, Pubann::Application.config.rdfizer_annotations), queue: :general
				Job.create({name:"Store RDFized annotations - #{project.name}", project_id:system.id, delayed_job_id:delayed_job.id})
			end
		rescue => e
			flash[:notice] = e.message
		end
		redirect_to project_path('system-maintenance')
	end

	def store_span_rdf
		begin
			raise RuntimeError, "Not authorized" unless current_user && current_user.root? == true
			project = Project.editable(current_user).find_by_name(params[:id])
			raise ArgumentError, "There is no such project." unless project.present?
			docids = project.docs.pluck(:id)
			system = Project.find_by_name('system-maintenance')

			delayed_job = Delayed::Job.enqueue StoreRdfizedSpansJob.new(system, docids, Pubann::Application.config.rdfizer_spans), queue: :general
			Job.create({name:"Store RDFized spans - #{project.name}", project_id:system.id, delayed_job_id:delayed_job.id})
		rescue => e
			flash[:notice] = e.message
		end
		redirect_to project_path('system-maintenance')
	end

	def clean
		begin
			raise RuntimeError, "Not authorized" unless current_user && current_user.root? == true

			projects = if params[:id].present?
				project = Project.find_by_name(params[:id])
				raise ArgumentError, "There is no such project." unless project.present?
				[project]
			else
				Project.all
			end

			system = Project.find_by_name('system-maintenance')

			projects.each do |project|
				project.clean
			end

			# projects.each do |project|
			#   delayed_job = Delayed::Job.enqueue StoreRdfizedAnnotationsJob.new(system, project.annotations_collection, Pubann::Application.config.rdfizer_annotations, project.name), queue: :general
			#   Job.create({name:"Store REDized annotations - #{project.name}", project_id:system.id, delayed_job_id:delayed_job.id})
			# end
		# rescue => e
		#   flash[:notice] = e.message
		end
		redirect_to project_path('system-maintenance')
	end

	def delete_all_docs
		begin
			project = Project.editable(current_user).find_by_name(params[:project_id])
			raise "The project does not exist, or you are not authorized to make a change to the project.\n" unless project.present?

			message = if project.has_doc?
				priority = project.jobs.unfinished.count

				# job = DeleteAllDocsFromProjectJob.new(project)
				# job.perform()

				delayed_job = Delayed::Job.enqueue DeleteAllDocsFromProjectJob.new(project), priority: priority, queue: :general
				Job.create({name:'Delete all docs', project_id:project.id, delayed_job_id:delayed_job.id})
				"The task, 'delete all docs', is created."
			else
				"The project had no document. Nothing happened.\n"
			end

			respond_to do |format|
				format.html {redirect_to project_path(project.name), notice: message}
				format.json {render json:{message: message}}
				format.txt  {render text:message}
			end
		rescue => e
			respond_to do |format|
				format.html {redirect_to project_path(project.name), notice: e.message}
				format.json {render json:{message: e.message}, status: :unprocessable_entity}
				format.txt  {render text:e.message, status: :unprocessable_entity}
			end
		end
	end

	def destroy_all_annotations
		begin
			project = Project.editable(current_user).find_by_name(params[:project_id])
			raise "The project does not exist, or you are not authorized to make a change to the project.\n" unless project.present?

			priority = project.jobs.unfinished.count
			taskname = 'Delete all annotations in project'
			delayed_job = Delayed::Job.enqueue DeleteAllAnnotationsFromProjectJob.new(project), priority: priority, queue: :general
			Job.create({name: taskname, project_id:project.id, delayed_job_id:delayed_job.id})
			message = "The task, '#{taskname}', is created."

			respond_to do |format|
				format.html {redirect_to project_path(project.name), notice: message}
				format.json {render json:{message: message}}
				format.txt  {render text:message}
			end
		rescue => e
			respond_to do |format|
				format.html {redirect_to project_path(project.name), notice: e.message}
				format.json {render json:{message: e.message}, status: :unprocessable_entity}
				format.txt  {render text:e.message, status: :unprocessable_entity}
			end
		end
	end

	# DELETE /projects/:name
	# DELETE /projects/:name.json
	def destroy
		project = Project.editable(current_user).find_by_name(params[:id])
		raise "There is no such project." unless project.present?

		sproject = Project.find_by_name('system-maintenance')

		priority = project.jobs.unfinished.count
		delayed_job = Delayed::Job.enqueue DestroyProjectJob.new(project), priority: priority, queue: :general
		Job.create({name:'Destroy project', project_id:sproject.id, delayed_job_id:delayed_job.id})

		respond_to do |format|
			format.html {redirect_to projects_path, status: :see_other, notice: "The project, #{@project.name}, will be deleted soon."}
			format.json {head :no_content }
		end
	end

	def clear_finished_jobs
		project = Project.editable(current_user).find_by_name(params[:project_id])
		raise "There is no such project." unless project.present?

		project.jobs.finished.each do |job|
			job.destroy_if_not_running
		end

		respond_to do |format|
			format.html { redirect_to project_jobs_path(project.name) }
			format.json { head :no_content }
		end
	end

	def autocomplete_project_author
		render json: Project.where(['author like ?', "%#{params[:term]}%"]).collect{|project| project.author}.uniq
	end

	def autocomplete_sourcedb
		project = Project.accessible(current_user).find_by_name(params[:id])
		render :json => project.docs.where("sourcedb ILIKE ?", "%#{params[:term]}%").pluck(:sourcedb).uniq
	end

	def autocomplete_project_name
		project_name_to_be_excluded = params[:id] || ''
		render :json => Project.accessible(current_user).where("name ILIKE ?", "%#{params[:term]}%").delete_if{|r| r.name == project_name_to_be_excluded}.collect{|r| {id:r.id, name:r.name, label:r.name}}
	end

	def autocomplete_editable_project_name
		project_name_to_be_excluded = params[:id] || ''
		render :json => Project.editable(current_user).where("name ILIKE ?", "%#{params[:term]}%").delete_if{|r| r.name == project_name_to_be_excluded}.collect{|r| {id:r.id, name:r.name, label:r.name}}
	end

	def is_owner?
		render_status_error(:forbidden) unless @project.present? && @project.user == current_user
	end
	
	def updatable?
		case params[:action]
		when 'edit'
			@project = Project.find_by_name(params[:id])
		when 'update'
			@project = Project.find(params[:id])
			if current_user == @project.user
				# add associate maintainers
				@project.build_associate_maintainers(params[:usernames])
			end
		end
		unless @project.editable?(current_user)
			render_status_error(:forbidden)
		end
	end
	
	def destroyable?
		@project = Project.find_by_name(params[:id])
		unless @project.destroyable?(current_user)
			render_status_error(:forbidden)
		end  
	end
end
