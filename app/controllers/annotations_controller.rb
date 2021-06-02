require 'fileutils'

class AnnotationsController < ApplicationController
	protect_from_forgery :except => [:create]
	before_action :authenticate_user!, :except => [:index, :align, :doc_annotations_index, :project_doc_annotations_index, :doc_annotations_list_view, :doc_annotations_merge_view, :project_annotations_tgz]
	include DenotationsHelper

	def index
		message = "The route does not exist.\n"
		respond_to do |format|
			format.html {redirect_to home_path, notice: message}
			format.json {render json: {message:message}, status: :unprocessable_entity}
			format.txt  {render text: message, status: :unprocessable_entity}
		end
	end

	# annotations for doc without project
	def doc_annotations_index
		@doc = Doc.find_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
		if @doc.present?
			@span = params[:begin].present? ? {:begin => params[:begin].to_i, :end => params[:end].to_i} : nil
			@doc.set_ascii_body if params[:encoding] == 'ascii'

			params[:project] = params[:projects] if params[:projects].present? && params[:project].blank?

			project = if params[:project].present?
				params[:project].split(',').uniq.map{|project_name| Project.accessible(current_user).find_by_name(project_name)}
			else
				@doc.projects
			end
			project.delete_if{|p| !p.annotations_accessible?(current_user)}

			context_size = params[:context_size].present? ? params[:context_size].to_i : 0

			options = {}
			options[:discontinuous_span] = params[:discontinuous_span].to_sym if params.has_key? :discontinuous_span
			@annotations = @doc.hannotations(project, @span, context_size, options)

			respond_to do |format|
				format.html {render 'index'}
				format.json {render json: @annotations}
			end
		else
			render_status_error(:not_found)
		end
	rescue => e
		respond_to do |format|
			format.html {redirect_to (@project.present? ? project_docs_path(@project.name) : home_path), notice: e.message}
			format.json {render json: {notice:e.message}, status: :unprocessable_entity}
		end
	end

	def project_doc_annotations_index
		@project = Project.find_by_name(params[:project_id])
		raise "There is no such project." unless @project.present?

		unless @project.public?
			authenticate_user!
			raise "annotations inaccessible" unless @project.annotations_accessible?(current_user)
		end

		@doc = @project.docs.find_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
		raise "Could not find the document in the project." unless @doc.present?

		@span = params[:begin].present? ? {:begin => params[:begin].to_i, :end => params[:end].to_i} : nil
		@doc.set_ascii_body if (params[:encoding] == 'ascii')
		# @content = @doc.body.gsub(/\n/, "<br>")

		context_size = params[:context_size].present? ? params[:context_size].to_i : 0

		@options = {sort: true}
		@options[:discontinuous_span] = params[:discontinuous_span].to_sym if params.has_key? :discontinuous_span
		@annotations = @doc.hannotations(@project, @span, context_size, @options)
		textae_config = @project ? @project.get_textae_config : nil

		respond_to do |format|
			format.html {render 'index_in_project'}
			format.json {render json: @annotations}
			format.tsv  {send_data Annotation.hash_to_tsv(@annotations, textae_config), filename: "#{params[:sourcedb]}-#{params[:sourceid]}.tsv"}
			format.dic  {send_data Annotation.hash_to_dic(@annotations), filename: "#{params[:sourcedb]}-#{params[:sourceid]}.dic"}
		end

	rescue => e
		respond_to do |format|
			format.html {redirect_to :back, notice: e.message}
			format.json {render json: {notice:e.message}, status: :unprocessable_entity}
			format.tsv  {render text: 'Error'}
		end
	end

	def doc_annotations_merge_view
		begin
			@doc = Doc.find_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
			raise "There is no such document in the project." unless @doc.present?
			annotations_merge_view
		rescue => e
			respond_to do |format|
				format.html {redirect_to home_path, notice: e.message}
				format.json {render json: {notice:e.message}, status: :unprocessable_entity}
			end
		end
	end

	def doc_annotations_list_view
		begin
			@doc = Doc.find_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
			raise "There is no such document in the project." unless @doc.present?
			annotations_list_view
		rescue => e
			respond_to do |format|
				format.html {redirect_to home_path, notice: e.message}
				format.json {render json: {notice:e.message}, status: :unprocessable_entity}
			end
		end
	end

	# POST /annotations
	# POST /annotations.json
	def create
		begin
			project = Project.editable(current_user).find_by_name(params[:project_id])
			raise "There is no such project in your management." unless project.present?

			annotations = if params[:annotations]
				params[:annotations].symbolize_keys
			elsif params[:text].present?
				{
					text: params[:text],
					denotations: params[:denotations].present? ? params[:denotations] : nil,
					relations: params[:relations].present? ? params[:relations] : nil,
					attributes: params[:attributes].present? ? params[:attributes] : nil,
					modification: params[:modification].present? ? params[:modification] : nil,
				}.delete_if{|k, v| v.nil?}
			else
				raise ArgumentError, t('controllers.annotations.create.no_annotation')
			end

			annotations[:sourcedb] = params[:sourcedb]
			annotations[:sourceid] = params[:sourceid]

			annotations = Annotation.normalize!(annotations)

			options = {}
			options[:mode] = params[:mode].present? ? params[:mode] : 'replace'
			options[:prefix] = params[:prefix] if params[:prefix].present?
			options[:span] = {begin: params[:begin].to_i, end: params[:end].to_i} if params[:begin].present? && params[:end].present?

			doc = project.docs.find_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
			unless doc.present?
				doc = project.add_doc(params[:sourcedb], params[:sourceid])
				unless doc == nil
					expire_fragment("sourcedb_counts_#{project.name}")
					expire_fragment("count_docs_#{project.name}")
					expire_fragment("count_#{params[:sourcedb]}_#{project.name}")
				end
			end
			raise "Could not add the document to the project." unless doc.present?

			doc.set_ascii_body if params[:encoding] == 'ascii'
			msgs = project.save_annotations!(annotations, doc, options)
			notice = "annotations saved."
			notice += "\n" + msgs.join("\n") unless msgs.empty?

			respond_to do |format|
				format.html {redirect_to :back, notice: notice}
				format.json {render json: annotations, status: :created}
			end

		rescue => e
			respond_to do |format|
				format.html {redirect_to (project.present? ? project_path(project.name) : home_path), notice: e.message}
				format.json {render :json => {error: e.message}, :status => :unprocessable_entity}
			end
		end
	end

	def align
		begin
			if params[:annotations]
				annotations = params[:annotations].symbolize_keys
			elsif params[:text].present?
				annotations = {:text => params[:text]}
				annotations[:denotations] = params[:denotations] if params[:denotations].present?
				annotations[:relations] = params[:relations] if params[:relations].present?
				annotations[:modifications] = params[:modifications] if params[:modifications].present?
			else
				raise ArgumentError, t('controllers.annotations.create.no_annotation')
			end

			annotations[:sourcedb] = params[:sourcedb]
			annotations[:sourceid] = params[:sourceid]

			annotations = Annotation.normalize!(annotations)
			annotations_collection = [annotations]

			doc = Doc.find_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
			unless doc.present?
				docs, messages = Doc.sequence_and_store_docs(params[:sourcedb], [params[:sourceid]])
				raise IOError, "Failed to get the document" unless docs.length == 1
				doc = docs.first
				expire_fragment("sourcedb_counts")
				expire_fragment("count_#{params[:sourcedb]}")
			end

			m = Annotation.prepare_annotations!(annotations, doc)

			respond_to do |format|
				format.json {render json: annotations}
			end

		rescue => e
			respond_to do |format|
				format.json {render :json => {error: e.message}, :status => :unprocessable_entity}
			end
		end
	end

	def obtain
		# get the project
		project = Project.editable(current_user).find_by_name(params[:project_id])
		raise ArgumentError, "Could not find the project: #{params[:project_id]}." unless project.present?

		# get the annotator
		annotator = if params[:annotator].present?
			Annotator.find(params[:annotator])
		elsif params[:url].present?
			Annotator.new({name:params[:prefix] || '-', url:params[:url], method:params[:method]})
		else
			raise ArgumentError, "Annotator URL is not specified"
		end

		# get the doc
		doc = project.docs.where(sourcedb: params[:sourcedb], sourceid: params[:sourceid]).first
		raise ArgumentError, "Could not find the document: #{params[:sourcedb]}:#{params[:sourceid]}" unless doc.present?

		# get the options
		options = {}
		options[:mode] = params[:mode] || 'replace'
		options[:prefix] = annotator.name
		options[:span] = {begin: params[:begin].to_i, end: params[:end].to_i} if params[:begin].present? && params[:end].present?

		raise "'skip' mode is not available." if options[:mode] == 'skip'

		text = doc.get_text(options[:span])
		message = if text.length < Annotator::MaxTextSync
			# job = ObtainDocAnnotationsJob.new(annotator, project, doc.id, options.merge(debug: true))
			job = ObtainDocAnnotationsJob.new(annotator, project, doc.id, options)
			res = job.perform()
			"Annotations were successfully obtained."
		else
			# job = ObtainDocAnnotationsJob.new(annotator, project, doc.id, options)
			# res = job.perform()
			priority = project.jobs.unfinished.count
			# delayed_job = Delayed::Job.enqueue ObtainDocAnnotationsJob.new(annotator, project, doc.id, options.merge(debug: true)), priority: priority, queue: :general
			delayed_job = Delayed::Job.enqueue ObtainDocAnnotationsJob.new(annotator, project, doc.id, options), priority: priority, queue: :general
			project.jobs.create({name:"Obtain annotations for a document: #{annotator.name}", delayed_job_id:delayed_job.id})
			"A background job was created to obtain annotations."
		end

		respond_to do |format|
			format.html {redirect_to :back, notice: message}
			format.json {}
		end
	rescue => e
		respond_to do |format|
			format.html {redirect_to :back, notice: e.message}
			format.json {render status: :service_unavailable}
		end
	end

	def obtain_batch
		begin
			project = Project.editable(current_user).find_by_name(params[:project_id])
			raise "Could not find the project: #{params[:project_id]}." unless project.present?
			raise "Up to 10 jobs can be registered per a project. Please clean your jobs page." unless project.jobs.count < 10

			# to determine the annotator
			annotator = if params[:annotator].present?
				Annotator.find(params[:annotator])
			elsif params[:url].present?
				Annotator.new({name:params[:prefix], url:params[:url], method:params[:method]})
			else
				raise ArgumentError, "Annotator URL is not specified"
			end

			# to determine the sourceids
			sourceids = if params[:upfile].present?
				File.readlines(params[:upfile].path).map(&:chomp)
			elsif params[:ids].present?
				params[:ids].split(/[ ,"':|\t\n\r]+/).map{|id| id.strip.sub(/^(PMC|pmc)/, '')}.uniq
			else
				[] # means all the docs in the project
			end

			# to determine the sourcedb
			raise ArgumentError, "Source DB is not specified." if sourceids.present? && !params['sourcedb'].present?
			sourcedb = params['sourcedb']

			# to determine the options
			options = {}
			options[:mode] = params[:mode] || 'replace'
			options[:prefix] = annotator.name

			# to deterine the docids
			docids = if options[:mode] == 'fill'
				options[:mode] == 'add'
				ProjectDoc.where(project_id:project.id, annotations_updated_at:nil).pluck(:doc_id)
			else
				sourceids.collect {|sourceid| project.docs.where(sourcedb:sourcedb, sourceid:sourceid).pluck(:id).first}
			end

			sourceid_indice_missing = docids.each_index.select{|i| docids[i].nil?}
			unless sourceid_indice_missing.empty?
				sourceids_missing = sourceid_indice_missing.collect{|i| sourceids[i]}
				raise ArgumentError, "Could not find the sourceid(s) in this project (sourcedb: #{sourcedb}): #{sourceids_missing.join(', ')}."
			end

			messages = []

			docids_filepath = begin
				# To update docids according to the options
				if options[:mode] == 'skip'
					num_skipped = if docids.empty?
						if ProjectDoc.where(project_id:project.id, denotations_num:0).count == 0
							raise RuntimeError, 'Obtaining annotation was skipped because all the docs already had annotations'
						end
						docids = ProjectDoc.where(project_id:project.id, denotations_num:0 ).pluck(:doc_id)
						ProjectDoc.where("project_id=#{project.id} and denotations_num > 0").count
					else
						num_docs = docids.length
						docids.delete_if{|docid| ProjectDoc.where(project_id:project.id, doc_id:docid).pluck(:denotations_num).first > 0}
						raise RuntimeError, 'Obtaining annotation was skipped because all the docs already had annotations' if docids.empty?
						num_docs - docids.length
					end

					messages << "#{num_skipped} document(s) was/were skipped due to existing annotations." if num_skipped > 0
					options[:mode] = 'add'
				else
					if docids.empty?
						docids = ProjectDoc.where(project_id:project.id).pluck(:doc_id)
					end
				end

				filepath = File.join('tmp', "obtain-#{project.name}-#{Time.now.to_s[0..18].gsub(/[ :]/, '-')}.txt")
				File.open(filepath, "w"){|f| f.puts(docids)}
				filepath
			end

			priority = project.jobs.unfinished.count

			# job = ObtainAnnotationsJob.new(project, docids_filepath, annotator, options)
			# job.perform()

			# delayed_job = Delayed::Job.enqueue ObtainAnnotationsJob.new(project, docids_filepath, annotator, options.merge(debug: true)), priority: priority, queue: :upload
			delayed_job = Delayed::Job.enqueue ObtainAnnotationsJob.new(project, docids_filepath, annotator, options), priority: priority, queue: :upload
			project.jobs.create({name:"Obtain annotations: #{annotator.name}", delayed_job_id:delayed_job.id})

			project.update_attributes({annotator_id:annotator.id}) if annotator.persisted?

			messages << "The task 'Obtain annotations was created."
			message = messages.join("\n")

			respond_to do |format|
				format.html {redirect_to :back, notice: message}
				format.json {}
			end
		rescue => e
			respond_to do |format|
				format.html {redirect_to :back, notice: e.message}
				format.json {render status: :service_unavailable}
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
			raise ArgumentError, "Unknown file type: '#{ext}'." unless ['.tgz', '.tar.gz', '.json'].include?(ext)

			raise "Up to 10 jobs can be registered per a project. Please clean your jobs page." unless project.jobs.count < 10

			options = {mode: params[:mode].present? ? params[:mode] : 'replace'}
			options[:duplicate_texts] = true if params[:duplicate_texts] == "1"
			options[:to_ignore_whitespaces] = true if params[:to_ignore_whitespaces] == "1"
			options[:to_ignore_text_order] = true if params[:to_ignore_text_order] == "1"

			filepath = File.join('tmp', "upload-#{params[:project_id]}-#{Time.now.to_s[0..18].gsub(/[ :]/, '-')}#{ext}")
			FileUtils.mv file.path, filepath

			if ext == '.json' && file.size < 20.kilobytes
				job = StoreAnnotationsCollectionUploadJob.new(filepath, project, options)
				res = job.perform()
				notice = "Annotations are successfully uploaded."
			else
				priority = project.jobs.unfinished.count
				delayed_job = Delayed::Job.enqueue StoreAnnotationsCollectionUploadJob.new(filepath, project, options), priority: priority, queue: :upload
				task = project.jobs.create({name: 'Upload annotations', delayed_job_id: delayed_job.id})
				notice = "The task, 'Upload annotations', is created."
			end

			respond_to do |format|
				format.html {redirect_to :back, notice: notice}
				format.json {render json: {message: notice, task_location: project_job_url(project.name, task.id, format: :json)}, status: :ok}
			end
		rescue => e
			respond_to do |format|
				format.html {redirect_to :back, notice: e.message}
				format.json {render json: {message: e.message}, status: :unprocessable_entity}
			end
		end
	end

	def delete_from_upload
		begin
			project = Project.editable(current_user).find_by_name(params[:project_id])
			raise "There is no such project in your management." unless project.present?

			ext = File.extname(params[:upfile].original_filename)
			if ['.tgz', '.tar.gz', '.json'].include?(ext)
				if project.jobs.count < 10
					options = {mode: params[:mode].present? ? params[:mode] : 'replace'}

					filepath = File.join('tmp', "delete-#{params[:project_id]}-#{Time.now.to_s[0..18].gsub(/[ :]/, '-')}.#{ext}")
					FileUtils.mv params[:upfile].path, filepath

					priority = project.jobs.unfinished.count
					delayed_job = Delayed::Job.enqueue DeleteAnnotationsFromUploadJob.new(filepath, project, options), priority: priority, queue: :upload
					project.jobs.create({name:'Delete annotations from documents', delayed_job_id:delayed_job.id})
					notice = "The task, 'Delete annotations from documents', is created."
				else
					notice = "Up to 10 jobs can be registered per a project. Please clean your jobs page."
				end
			else
				notice = "Unknown file type: '#{ext}'."
			end
		rescue => e
			notice = e.message
		end

		respond_to do |format|
			format.html {redirect_to :back, notice: notice}
			format.json {}
		end
	end


	# redirect to project annotations tgz
	def project_annotations_tgz
		begin
			project = Project.accessible(current_user).find_by_name(params[:project_id])
			raise "There is no such project." unless project.present?

			if File.exist?(project.annotations_tgz_system_path)
				redirect_to project.annotations_tgz_path
			else
				raise "annotation tgz file does not exist."
			end
		rescue => e
			render_status_error(:not_found)
		end
	end

	def import
		begin
			project = Project.editable(current_user).find_by_name(params[:project_id])
			raise "There is no such project in your management: #{params[:project_id]}." unless project.present?

			source_project = Project.find_by_name(params[:select_project])
			raise ArgumentError, "Could not find the project: #{params[:select_project]}." if source_project.nil?
			raise ArgumentError, "You cannot import annotations from itself." if source_project == project
			raise ArgumentError, "The annotations in the project are blinded." if source_project.accessibility == 3

			source_docs = source_project.docs
			destin_docs = project.docs
			shared_docs = source_docs & destin_docs

			raise ArgumentError, "There is no shared document with the project, #{source_project.name}" if shared_docs.length == 0
			raise ArgumentError, "For a performance reason, current implementation limits this feature to work for less than 3,000 documents." if shared_docs.length > 3000

			docids = shared_docs.collect{|d| d.id}

			priority = project.jobs.unfinished.count
			delayed_job = Delayed::Job.enqueue ImportAnnotationsJob.new(source_project, project), priority: priority, queue: :general
			project.jobs.create({name:"Import annotations from #{source_project.name}", delayed_job_id:delayed_job.id})
			message = "The task, 'import annotations from the project, #{source_project.name}', is created."

		rescue => e
			message = e.message
		end

		respond_to do |format|
			format.html {redirect_to project_path(project.name), notice: message}
			format.json {render json:{message:message}}
		end
	end

	def create_project_annotations_tgz
		begin
			project = Project.editable(current_user).find_by_name(params[:project_id])
			raise "There is no such project in your management." unless project.present?

			# job = CreateAnnotationsTgzJob.new(project, {})
			# job.perform

			priority = project.jobs.unfinished.count
			delayed_job = Delayed::Job.enqueue CreateAnnotationsTgzJob.new(project, {}), priority: priority, queue: :general
			project.jobs.create({name:'Create a downloadable archive', delayed_job_id:delayed_job.id})

			redirect_to :back, notice: "The task 'Create a downloadable archive' is created."
		rescue => e
			redirect_to home_path, notice: e.message
		end
	end


	def delete_project_annotations_tgz
		begin
			status_error = false
			project = Project.editable(current_user).find_by_name(params[:project_id])
			raise "There is no such project." unless project.present?

			if File.exist?(project.annotations_tgz_system_path)
				if project.editable?(current_user)
					File.unlink(project.annotations_tgz_system_path)
					flash[:notice] = t('views.shared.download.deleted')
				else
					status_error = true
					render_status_error(:forbidden)
				end
			else
				status_error = true
				render_status_error(:not_found)
			end
		rescue => e
			flash[:notice] = e.message
		ensure
			redirect_to :back if status_error == false
		end
	end

	def project_annotations_rdf
		begin
			project = Project.accessible(current_user).find_by_name(params[:project_id])
			raise "There is no such project." unless project.present?

			if File.exist?(project.annotations_rdf_system_path)
				# redirect_to "/annotations/#{project.annotations_rdf_file_name}"
				redirect_to project.annotations_rdf_path
			else
				raise "annotation rdf file does not exist."
			end
		rescue => e
			render_status_error(:not_found)
		end
	end

	def delete_project_annotations_rdf
		begin
			status_error = false
			project = Project.editable(current_user).find_by_name(params[:project_id])
			raise "There is no such project." unless project.present?

			if File.exist?(project.annotations_rdf_system_path)
				if project.user == current_user 
					File.unlink(project.annotations_rdf_system_path)
					flash[:notice] = t('views.shared.rdf.deleted')
				else
					status_error = true
					render_status_error(:forbidden)
				end
			else
				status_error = true
				render_status_error(:not_found)
			end
		rescue => e
			flash[:notice] = e.message
		ensure
			redirect_to :back if status_error == false
		end
	end

	def destroy
		begin
			project = Project.editable(current_user).find_by_name(params[:project_id])
			raise "Could not find the project." unless project.present?

			doc = project.docs.find_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
			raise "Could not find the document." unless doc.present?

			doc.set_ascii_body if params[:encoding] == 'ascii'

			span = {begin: params[:begin].to_i, end: params[:end].to_i} if params[:begin].present? && params[:end].present?
			project.delete_doc_annotations(doc, span)

			respond_to do |format|
				format.html {redirect_to :back, notice: "annotations deleted"}
				format.json {render status: :no_content}
			end
		rescue => e
			redirect_to :back, notice: e.message
		end
	end

	private

	def annotations_merge_view
		@span = params[:begin].present? ? {:begin => params[:begin].to_i, :end => params[:end].to_i} : nil
		@doc.set_ascii_body if params[:encoding] == 'ascii'

		pnames_concat = params[:projects]

		all_projects = @doc.projects.annotations_accessible(current_user)
		if pnames_concat.present?
			pnames = pnames_concat.split(',').uniq
			@in_projects = all_projects.select{|p| pnames.include? p.name}
			@out_projects = all_projects - @in_projects
		else
			@in_projects = all_projects
		end

		context_size = params[:context_size].to_i

		@annotations = @doc.hannotations(@in_projects, @span, context_size)
		Annotation.add_source_project_color_coding!(@annotations)

		respond_to do |format|
			format.html {render 'merge_view'}
			format.json {render json: @annotations}
		end
	end

	def annotations_list_view
		@span = params[:begin].present? ? {:begin => params[:begin].to_i, :end => params[:end].to_i} : nil
		@doc.set_ascii_body if params[:encoding] == 'ascii'

		if params[:projects].present?
			project_names = params[:projects].split(',').uniq
			@visualize_projects = Array.new
			projects = Project.accessible(current_user).where(['name IN (?)', project_names]).annotations_accessible(current_user)
			project_names.each do |project_name|
				@visualize_projects.push projects.detect{|project| project.name == project_name}
			end

			@non_visualize_projects = @doc.projects.accessible(current_user).annotations_accessible(current_user) - @visualize_projects
		else
			@visualize_projects = @doc.projects.accessible(current_user).annotations_accessible(current_user)
		end

		context_size = params[:context_size].present? ? params[:context_size].to_i : 0

		@annotations = @doc.hannotations(@visualize_projects, @span, context_size)
		@track_annotations = @annotations[:tracks]
		@track_annotations.each {|a| a[:text] = @annotations[:text]}

		respond_to do |format|
			format.html {render 'list_view'}
			format.json {render json: @annotations}
		end
	end
end
