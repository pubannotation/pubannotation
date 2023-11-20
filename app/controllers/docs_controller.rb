require 'zip/zip'

class DocsController < ApplicationController
	include HttpBasicAuthenticatable

	protect_from_forgery :except => [:create]
	before_action :authenticate_user!, :only => [:new, :create, :create_from_upload, :edit, :update, :destroy, :project_delete_doc, :project_delete_all_docs, :uptodate]
	before_action :http_basic_authenticate, :only => :create, :if => Proc.new{|c| c.request.format == 'application/jsonrequest'}
	skip_before_action :authenticate_user!, :verify_authenticity_token, :if => Proc.new{|c| c.request.format == 'application/jsonrequest'}

	autocomplete :doc, :sourcedb

	def index
		if params[:project_id].present?
			@project = Project.accessible(current_user).find_by(name: params[:project_id])
			raise ArgumentError, "Could not find the project." unless @project.present?
		end

		@sourcedb = params[:sourcedb]

		page = (params[:page].presence || 1).to_i
		per  = (params[:per].presence || 10).to_i

		raise ArgumentError, "The value of 'page' must be bigger than or equal to 1." if page < 1
		raise ArgumentError, "The value of 'per' must be bigger than or equal to 1." if per < 1
		raise ArgumentError, "The value of 'per' must be less than or equal to 10,000." if per > 10000

		# If a keyword parameter is specified, Elasticsearch is used to search the full text of the Doc.
		# The results will also include a text string highlighting the matches in the full-text search.
		use_elasticsearch = params[:keywords].present?

		if use_elasticsearch
			project_id = @project.nil? ? nil : @project.id
			search_results = Doc.search_docs({body: params[:keywords].strip.downcase, project_id: project_id, sourcedb: @sourcedb, page:page, per:per})
			@search_count = search_results.results.total
			htexts = search_results.results.map{|r| {text: r.highlight.body}}
			@docs = search_results.records
		else
			sort_order = if params[:sort_key].present? && params[:sort_direction].present?
										 "#{params[:sort_key]} #{params[:sort_direction]}"
									 else
										 Doc.sort_order(@project || nil)
									 end

			if params[:randomize]
				sort_order = sort_order ? sort_order + ', ' : ''
				sort_order += 'random()'
			end

			@docs = Doc.all
			@docs = @docs.joins(:projects).where(projects: {id: @project.id}) if @project.present?
			@docs = @docs.where(sourcedb: @sourcedb) if @sourcedb.present?
			@docs.order(sort_order).simple_paginate(page, per)
		end

		respond_to do |format|
			format.html do
				if use_elasticsearch
					@docs = @docs.map.with_index do |doc, index|
						htext = htexts[index]
						doc.body = htext[:text].first
						doc
					end
				end
			end
			format.json do
				hdocs = @docs.map { |d| d.to_list_hash }
				if use_elasticsearch
					hdocs = hdocs.map.with_index do |doc, index|
						htext = htexts[index]
						doc[:text] = htext[:text]
						doc
					end
				end
				send_data hdocs.to_json, filename: "docs-list-#{per}-#{page}.json", type: :json, disposition: :inline
			end
			format.tsv do
				hdocs = @docs.map { |d| d.to_list_hash }
				if use_elasticsearch
					hdocs = hdocs.map.with_index do |doc, index|
						htext = htexts[index]
						doc[:text] = htext[:text].first
						doc
					end
				end
				send_data Doc.hash_to_tsv(hdocs), filename: "docs-list-#{per}-#{page}.tsv", type: :tsv, disposition: :inline
			end
		end
	rescue => e
		logger.debug "[DEBUG] #{e.class}: #{e.message}"
		respond_to do |format|
			format.html {redirect_to (@project.present? ? project_path(@project.name) : home_path), notice: e.message}
			format.json {render json: {message:e.message}, status: :unprocessable_entity}
			format.tsv  {render plain: e.message, status: :unprocessable_entity}
		end
	end
 
	def sourcedb_index
		begin
			if params[:project_id].present?
				@project = Project.accessible(current_user).find_by_name(params[:project_id])
				raise "There is no such project." unless @project.present?
			end

		rescue => e
			respond_to do |format|
				format.html {redirect_back fallback_location: root_path, flash: { notice: e.message }}
			end
		end
	end 

	def show
		begin
			sourcedb = params[:sourcedb]
			sourceid = params[:sourceid]

			docs = Doc.where(sourcedb:sourcedb, sourceid:sourceid)

			unless docs.present?
				docs, messages = Doc.sequence_and_store_docs(sourcedb, [sourceid])
				raise "Could not find the document, #{sourcedb}:#{sourceid}. The document may not be in the Open Access Subset of PMC, or PMC is not responding now." unless docs.present?
			end

			raise "Multiple entries for #{params[:sourcedb]}:#{params[:sourceid]} found." if docs.length > 1

			@doc = docs.first
			@span = if params.has_key?(:begin) && params.has_key?(:end)
				{:begin => params[:begin].to_i, :end => params[:end].to_i}
			else
				nil
			end

			@doc.set_ascii_body if params[:encoding] == 'ascii'

			get_docs_projects
			if @span
				valid_projects = @doc.get_projects(@span)
				@projects = @projects & valid_projects
			end

			respond_to do |format|
				format.html
				format.json {render json: @doc.to_hash(@span)}
				format.txt  {render plain: @doc.get_text(@span)}
			end

		rescue => e
			respond_to do |format|
				format.html {redirect_to (@project.present? ? project_docs_path(@project.name) : home_path), notice: e.message}
				format.json {render json: {notice:e.message}, status: :unprocessable_entity}
				format.txt  {render plain: e.message, status: :unprocessable_entity}
			end
		end
	end

	def show_in_project
		begin
			@project = Project.accessible(current_user).find_by_name(params[:project_id])
			raise "Could not find the project." unless @project.present?

			docs = @project.docs.where(sourcedb: params[:sourcedb], sourceid: params[:sourceid])
			raise "Could not find the document, #{params[:sourcedb]}:#{params[:sourceid]}, within this project." unless docs.present?
			raise "Multiple entries for #{params[:sourcedb]}:#{params[:sourceid]} found." if docs.length > 1

			@doc = docs.first
			@span = if params.has_key?(:begin) && params.has_key?(:end)
				{:begin => params[:begin].to_i, :end => params[:end].to_i}
			else
				nil
			end

			@doc.set_ascii_body if (params[:encoding] == 'ascii')

			respond_to do |format|
				format.html
				format.json {render json: @doc.to_hash(@span)}
				format.txt  {render plain: @doc.get_text(@span)}
			end

		rescue => e
			respond_to do |format|
				format.html {redirect_to (@project.present? ? project_docs_path(@project.name) : home_path), notice: e.message}
				format.json {render json: {notice:e.message}, status: :unprocessable_entity}
				format.txt  {render status: :unprocessable_entity}
			end
		end
	end

	def open
		params[:sourceid].strip!
		begin
			if params[:project_id].present?
				respond_to do |format|
					format.html {redirect_to show_project_sourcedb_sourceid_docs_path(params[:project_id], params[:sourcedb], params[:sourceid])}
				end
			else
				respond_to do |format|
					format.html {redirect_to doc_sourcedb_sourceid_show_path(params[:sourcedb], params[:sourceid])}
				end
			end

		rescue => e
			respond_to do |format|
				format.html {redirect_back fallback_location: root_path, flash: { notice: e.message }}
			end
		end
	end

	# GET /docs/new
	# GET /docs/new.json
	def new
		@doc = Doc.new
		begin 
			@project = get_project2(params[:project_id])
		rescue => e
			notice = e.message
		end
		respond_to do |format|
			format.html # new.html.erb
			format.json {render json: @doc.to_hash}
		end
	end

	# POST /docs
	# POST /docs.json
	# Creation of document is only allowed for single division documents.
	def create
		begin
			raise ArgumentError, "project id has to be specified." unless params[:project_id].present?

			@project = Project.editable(current_user).find_by_name(params[:project_id])
			raise "The project does not exist, or you are not authorized to make a change to the project.\n" unless @project.present?

			hdoc = if doc_params.present? && params[:commit].present?
				doc_params
			else
				text = if params[:text]
					params[:text]
				elsif request.content_type =~ /text/
					request.body.read
				end

				raise "Could not find text." unless text.present?

				_doc = {
					source: params[:source],
					sourcedb: params[:sourcedb] || '',
					sourceid: params[:sourceid],
					body: text
				}

				_doc[:divisions] = params[:divisions] if params[:divisions].present?
				_doc[:typesettings] = params[:typesettings] if params[:typesettings].present?
				_doc
			end

			hdoc = Doc.hdoc_normalize!(hdoc, current_user, current_user.root?)
			@doc = Doc.store_hdoc!(hdoc)
			@project.add_doc!(@doc)

			respond_to do |format|
				format.html { redirect_to show_project_sourcedb_sourceid_docs_path(@project.name, hdoc[:sourcedb], hdoc[:sourceid]), notice: t('controllers.shared.successfully_created', :model => t('activerecord.models.doc')) }
				format.json { render json: @doc.to_hash, status: :created, location: @doc }
			end
		rescue => e
			respond_to do |format|
				format.html { redirect_to new_project_doc_path(@project.name), notice: e.message }
				format.json { render json: {message: e.message}, status: :unprocessable_entity }
			end
		end
	end

	def create_from_upload
		begin
			project = Project.editable(current_user).find_by_name(params[:project_id])
			raise ArgumentError, "Could not find the project." unless project.present?

			file = params[:upfile]

			filename = file.original_filename
			ext = File.extname(filename).downcase
			ext = '.tar.gz' if ext == '.gz' && filename.end_with?('.tar.gz')
			raise ArgumentError, "Unknown file type: '#{ext}'." unless ['.tgz', '.tar.gz', '.json', '.txt'].include?(ext)

			options = {
				mode: params[:mode].present? ? params[:mode].to_s : "update",
				root: current_user.root?
			}

			dirpath = File.join('tmp/uploads', "#{params[:project_id]}-#{Time.now.to_s[0..18].gsub(/[ :]/, '-')}")
			FileUtils.mkdir_p dirpath
			FileUtils.mv file.path, File.join(dirpath, filename)

			if ['.json', '.txt'].include?(ext) && file.size < 100.kilobytes
				UploadDocsJob.perform_now(project, dirpath, options, filename)
				notice = "Documents are successfully uploaded."
			else
				raise "Up to 10 jobs can be registered per a project. Please clean your jobs page." unless project.jobs.count < 10

				# UploadDocsJob.perform_now(project, dirpath, options, filename)

				active_job = UploadDocsJob.perform_later(project, dirpath, options, filename)
				notice = "The task, '#{active_job.job_name}', is created."
			end
		rescue => e
			notice = e.message
		end

		respond_to do |format|
			format.html {redirect_back fallback_location: root_path, flash: { notice: notice }}
			format.json {}
		end
	end

	# GET /docs/1/edit
	def edit
		begin
			raise RuntimeError, "Not authorized" unless current_user && current_user.root? == true

			docs = Doc.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
			raise "There is no such document" unless docs.present?
			raise "Multiple entries for #{params[:sourcedb]}:#{params[:sourceid]} found." if docs.length > 1

			@doc = docs[0]
		rescue => e
			respond_to do |format|
				format.html {redirect_to (@project.present? ? project_docs_path(@project.name) : home_path), notice: e.message}
			end
		end
	end

	# PUT /docs/1
	# PUT /docs/1.json
	def update
		raise RuntimeError, "Not authorized" unless current_user && current_user.root? == true

		params = doc_params
		params[:body].gsub!(/\r\n/, "\n")
		@doc = Doc.find(params[:id])

		respond_to do |format|
			if @doc.update(params)
				format.html { redirect_to @doc, notice: t('controllers.shared.successfully_updated', :model => t('activerecord.models.doc')) }
				format.json { head :no_content }
			else
				format.html { render action: "edit" }
				format.json { render json: @doc.errors, status: :unprocessable_entity }
			end
		end
	end

	# add new docs to a project
	def add_from_upload
		project = Project.editable(current_user).find_by_name(params[:project_id])
		raise "The project does not exist, or you are not authorized to make a change to the project.\n" unless project.present?
		raise ArgumentError, "sourcedb is not specified." unless params["sourcedb"].present?

		sourcedb = params["sourcedb"]
		filename = params[:upfile].original_filename
		ext = File.extname(filename)
		raise ArgumentError, "Unknown file type: '#{ext}'." unless ['.txt'].include?(ext)

		raise "Up to 10 jobs can be registered per a project. Please clean your jobs page." unless project.jobs.count < 10

		filepath = File.join('tmp', "add-docs-to-#{params[:project_id]}-#{Time.now.to_s[0..18].gsub(/[ :]/, '-')}#{ext}")
		FileUtils.mv params[:upfile].path, filepath

		# AddDocsToProjectFromUploadJob.perform_now(project, sourcedb, filepath)

		active_job = AddDocsToProjectFromUploadJob.perform_later(project, sourcedb, filepath)
		job = Job.find_by(active_job_id: active_job.job_id)
		message = "The task, '#{active_job.job_name}', is created."

		respond_to do |format|
			format.html {redirect_back fallback_location: root_path, notice: message }
			format.json {render json: {message: message, task_location: project_job_url(project.name, job.id, format: :json)}, status: :ok}
		end
	rescue => e
		respond_to do |format|
			format.html {redirect_back fallback_location: root_path, notice: e.message }
			format.json {render json: {message: e.message}, status: :unprocessable_entity}
		end
	end

	# add new docs to a project
	def add
		message = begin
			project = Project.editable(current_user).find_by_name(params[:project_id])
			raise "No project by the name exists under your management." unless project.present?

			# get the docspecs list
			docspecs =  if params["_json"] && params["_json"].class == Array
										params["_json"].collect{|d| d.symbolize_keys}
									elsif params["sourcedb"].present? && params["sourceid"].present?
										[{sourcedb:params["sourcedb"], sourceid:params["sourceid"]}]
									elsif params[:ids].present? && params[:sourcedb].present?
										params[:ids].strip.split(/[ ,"':|\t\n\r]+/).collect{|id| id.strip}.collect{|id| {sourcedb:params[:sourcedb], sourceid:id}}
									else
										[]
									end

			raise ArgumentError, "no valid document specification found." if docspecs.empty?

			docspecs.each{|d| d[:sourceid].sub!(/^(PMC|pmc)/, '')}
			docspecs.uniq!

			if docspecs.length == 1
				docspec = docspecs.first
			    doc = Doc.find_by(sourcedb: docspec[:sourcedb], sourceid: docspec[:sourceid]) \
			            || Doc.sequence_and_store_doc!(docspec[:sourcedb], docspec[:sourceid])
			    project.add_doc!(doc)
				"#{docspec[:sourcedb]}:#{docspec[:sourceid]} - added."
			else
				# AddDocsToProjectJob.perform_later(project, docspecs)
				AddDocsToProjectJob.perform_now(project, docspecs)
				"The task, 'add documents to the project', is created."
			end
		# rescue => e
		# 	e.message
		end

		respond_to do |format|
			format.html {redirect_back fallback_location: root_path, flash: { notice: message}}
			format.json {render json:{message:message}}
		end
	end

	def import
		message = begin
			project = Project.editable(current_user).find_by! name: params[:project_id]

			source_project = Project.find_by name: params["select_project"]
			raise ArgumentError, "The project (#{params["select_project"]}) does not exist, or you are not authorized to access it.\n" unless source_project.present?
			raise ArgumentError, "You cannot import documents from itself." if source_project == project

			ImportDocsJob.perform_later(project, source_project.id)

			"The task, 'import documents to the project', is created."
		rescue ActiveRecord::RecordNotFound => e
			raise "No project by the name exists under your management."
		rescue => e
			e.message
		end

		respond_to do |format|
			format.html {redirect_back fallback_location: root_path, flash: { notice: message }}
			format.json {render json:{message:message}}
		end
	end

	def uptodate
		if current_user.root?
			doc = Doc.where(sourcedb:params[:sourcedb], sourceid:params[:sourceid]).first
			if doc.present?
				p = {
					size_ngram: params[:size_ngram],
					size_window: params[:size_window],
					threshold: params[:threshold]
				}.compact

				Doc.uptodate(doc)
				message = "The document #{doc.descriptor} was successfully updated."
				redirect_to doc_sourcedb_sourceid_show_path(params[:sourcedb], params[:sourceid]), notice: message
			else
				render_status_error(:not_found)
			end
		else
			render_status_error(:forbidden)
		end
	rescue => e
		redirect_back fallback_location: root_path, flash: { notice: e.message }
	end

	# DELETE /docs/sourcedb/:sourcedb/sourceid/:sourceid
	def delete
		raise SecurityError, "Not authorized" unless current_user && current_user.root? == true

		docs = Doc.where(sourcedb:params[:sourcedb], sourceid:params[:sourceid])
		raise "Could not find the document." unless docs.present?
		raise "Multiple entries for #{params[:sourcedb]}:#{params[:sourceid]} found." if docs.length > 1

		doc = docs.first
		sourcedb = doc.sourcedb
		doc.destroy

		redirect_to doc_sourcedb_index_path(sourcedb)
	end

	# DELETE /docs/1
	# DELETE /docs/1.json
	def destroy
		begin
			doc = Doc.find(params[:id])
			if params[:project_id].present?
				project = Project.editable(current_user).find_by name: params[:project_id]
				raise "No project by the name exists under your management." unless project.present?
				project.delete_doc(doc)

				redirect_path = project_docs_path(params[:project_id])
			else
				raise SecurityError, "Not authorized" unless current_user && current_user.root? == true
				doc.destroy
				redirect_path = home_path
			end

			message = 'the document is deleted from the project.'
			respond_to do |format|
				format.html { redirect_to redirect_path }
				format.json { render json: {message: message} }
				format.txt  { render plain: message }
			end
		rescue => e
			respond_to do |format|
				format.html { redirect_to redirect_path, notice: e.message }
				format.json { render json: {message: e.message}, status: :unprocessable_entity }
				format.txt  { render plain: e.message, status: :unprocessable_entity }
			end
		end
	end

	def project_delete_doc
		project = Project.editable(current_user).find_by name: params[:project_id]
		raise "Could not find the project, or you are not authorized to make a change to the project.\n" unless project.present?

		doc = project.docs.find_by sourcedb:params[:sourcedb], sourceid:params[:sourceid]
		raise "Could not find the document." unless doc.present?

		project.delete_doc(doc)

		message = "the document is deleted from the project.\n"

		respond_to do |format|
			format.html { redirect_to project_docs_path(project.name), notice:message }
			format.json { render json: {message: message} }
			format.txt  { render plain: message }
		end
	rescue => e
		respond_to do |format|
			format.html { redirect_to project_docs_path(project.name), notice:e.message }
			format.json { render json: {message: e.message}, status: :unprocessable_entity }
			format.txt  { render plain: e.message, status: :unprocessable_entity }
		end
	end

	def store_span_rdf
		begin
			raise RuntimeError, "Not authorized" unless current_user && current_user.root? == true

			projects = Project.for_index
			docids = projects.inject([]){|col, p| (col + p.docs.pluck(:id))}.uniq
			system = Project.admin_project

			StoreRdfizedSpansJob.perform_later(system, docids, Pubann::Application.config.rdfizer_spans)
		rescue => e
			flash[:notice] = e.message
		end
		redirect_to project_path(system.name)
	end

	def update_numbers
		raise RuntimeError, "Not authorized" unless current_user && current_user.root? == true

		active_job = UpdateNumbersForDocsJob.perform_later(Project.admin_project)

		result = {message: "The task, '#{active_job.job_name}', created."}
		redirect_to project_path(Project.admin_project.name)
	rescue => e
		flash[:notice] = e.message
		redirect_to home_path
	end

	# def autocomplete_sourcedb
	#   render :json => Doc.where(['LOWER(sourcedb) like ?', "%#{params[:term].downcase}%"]).collect{|doc| doc.sourcedb}.uniq
	# end
	private

	def doc_params
		params.require(:doc).permit(:body, :source, :sourcedb, :sourceid, :username)
	end

	def get_project2 (project_name)
		project = Project.find_by_name(project_name)
		raise ArgumentError, I18n.t('controllers.application.get_project.not_exist', :project_name => project_name) unless project.present?
		raise ArgumentError, I18n.t('controllers.application.get_project.private', :project_name => project_name) unless (project.accessibility == 1 || (user_signed_in? && project.user == current_user))
		project
	end

	def get_docs_projects
		sort_order = if params[:sort_key].present? && params[:sort_direction].present?
									 "#{params[:sort_key]} #{params[:sort_direction]}"
								 else
									 nil
								 end

		@projects = @doc.projects.annotations_accessible(current_user).order(sort_order)
		if params[:projects].present?
			select_project_names = params[:projects].split(',').uniq
			@selected_projects = select_project_names.collect{|pname| Project.where(name:pname).first}
			@projects -= @selected_projects
		end
	end
end
