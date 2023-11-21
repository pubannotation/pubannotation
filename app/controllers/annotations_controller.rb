class AnnotationsController < ApplicationController
	protect_from_forgery :except => [:create]
	before_action :authenticate_user!, :except => [:create, :index, :align, :doc_annotations_index, :project_doc_annotations_index, :doc_annotations_list_view, :doc_annotations_merge_view, :project_annotations_tgz]
	include DenotationsHelper

	def index
		message = "The route does not exist.\n"
		respond_to do |format|
			format.html {redirect_to home_path, notice: message}
			format.json {render json: {message:message}, status: :unprocessable_entity}
			format.txt  {render plain: message, status: :unprocessable_entity}
		end
	end

	# annotations for doc without project
	def doc_annotations_index
		@doc = Doc.find_by(sourcedb: params[:sourcedb], sourceid: params[:sourceid])
		return render_status_error(:not_found) unless @doc.present?

		@span = params[:begin].present? ? {:begin => params[:begin].to_i, :end => params[:end].to_i} : nil
		@doc.set_ascii_body if params[:encoding] == 'ascii'

		params[:project] = params[:projects] if params[:projects].present? && params[:project].blank?

		project = if params[:project].present?
								params[:project].split(',').uniq.map do |project_name|
									Project.accessible(current_user).find_by_name(project_name)
								end
							else
								@doc.projects.to_a
							end
		project.delete_if{|p| !p.annotations_accessible?(current_user)}

		context_size = params[:context_size].present? ? params[:context_size].to_i : 0
		terms = params[:terms].present? ? params[:terms].split(',').map{|term| term.strip} : nil
		predicates = params[:predicates].present? ? params[:predicates].split(',').map{|predicate| predicate.strip} : nil
		is_bag_denotations = params[:discontinuous_span].present? && params[:discontinuous_span] == 'bag'
		@annotations = @doc.hannotations(project, @span, context_size, terms:, predicates:, is_bag_denotations:)

		respond_to do |format|
			format.html {render 'index'}
			format.json {render json: @annotations}
		end
	rescue => e
		Rails.logger.error e.message

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
		@annotations = @doc.hannotations(@project, @span, context_size, is_sort: true, is_bag_denotations: @options[:discontinuous_span] == :bag)
		textae_config = @project ? @project.get_textae_config : nil

		respond_to do |format|
			format.html {render 'index_in_project'}
			format.json {render json: @annotations}
			format.tsv  {send_data AnnotationUtils.hash_to_tsv(@annotations, textae_config), filename: "#{params[:sourcedb]}-#{params[:sourceid]}.tsv"}
			format.dic  {send_data AnnotationUtils.hash_to_dic(@annotations), filename: "#{params[:sourcedb]}-#{params[:sourceid]}.dic"}
		end

	rescue => e
		respond_to do |format|
			format.html {redirect_back fallback_location: root_path, notice: e.message}
			format.json {render json: {notice:e.message}, status: :unprocessable_entity}
			format.tsv  {render plain: 'Error'}
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
		unless user_signed_in? then
			response.headers['WWW-Authenticate'] = 'ServerPage'
			response.headers['Location'] = new_user_session_url
			response.headers['Access-Control-Expose-Headers'] = 'WWW-Authenticate, Location'
			head 401 and return
		end

		# use unsafe params for flexible paramater passing
		unsafe_params = params.permit!.to_hash.deep_symbolize_keys!


		##########
		# determine the project
		##########
		project = begin
			if unsafe_params.has_key? :project_id
				# if a project is specified in the path, it should exists and accessible. Otherwise an exception should be thrown.
				_project = Project.editable(current_user).find_by! name: unsafe_params[:project_id]
			else
				# if a project is specified in the annotation, better to use it
				_project = Project.editable(current_user).find_by_name(unsafe_params[:project]) if unsafe_params.has_key? :project

				# return _project if present. Otherwise return the default project of the current user
				_project || _project = current_user.default_project
			end
		rescue ActiveRecord::RecordNotFound => e
			raise "No project by the name exists under your management."
		end


		##########
		# determine the document
		##########
		doc = if params[:sourcedb] && params[:sourceid]
		    _doc = Doc.find_by(sourcedb: params[:sourcedb], sourceid: params[:sourceid]) \
		            || Doc.sequence_and_store_doc!(params[:sourcedb], params[:sourceid])
			project.add_doc!(_doc) unless project.has_doc?(_doc)
			_doc
		else
			raise "Text is missing." unless params.has_key? :text

			# Create a doc
			hdoc = {body: params[:text]}
			hdoc[:source] = params[:source] if params[:source].present?
			hdoc[:divisions] = params[:divisions] if params[:divisions].present?
			hdoc[:typesettings] = params[:typesettings] if params[:typesettings].present?

			hdoc = Doc.hdoc_normalize!(hdoc, current_user, current_user.root?)
			_doc = Doc.store_hdoc!(hdoc)
			project.add_doc!(_doc)
		end


		##########
		# determine the annotation
		##########
		annotations = if unsafe_params[:annotations]
			unsafe_params[:annotations].to_hash.to_json
		elsif unsafe_params[:text].present?
			{
				text: unsafe_params[:text],
				denotations: unsafe_params[:denotations].present? ? unsafe_params[:denotations] : nil,
				blocks: unsafe_params[:blocks].present? ? unsafe_params[:blocks] : nil,
				relations: unsafe_params[:relations].present? ? unsafe_params[:relations] : nil,
				attributes: unsafe_params[:attributes].present? ? unsafe_params[:attributes] : nil
			}.delete_if{|k, v| v.nil?}
		else
			raise ArgumentError, t('controllers.annotations.create.no_annotation')
		end

		annotations = AnnotationUtils.normalize!(annotations)


		options = {}
		options[:mode] = params[:mode].present? ? params[:mode] : 'replace'
		options[:prefix] = params[:prefix] if params[:prefix].present?
		options[:span] = {begin: params[:begin].to_i, end: params[:end].to_i} if params[:begin].present? && params[:end].present?

		doc.set_ascii_body if params[:encoding] == 'ascii'
		msgs = project.save_annotations!(annotations, doc, options)
		notice = "annotations saved."
		notice += "\n" + msgs.join("\n") unless msgs.empty?

		respond_to do |format|
			format.html {redirect_back fallback_location: root_path, notice: notice}
			format.json {render json: annotations, status: :created}
		end

	rescue => e
		respond_to do |format|
			format.html {redirect_to (project.present? ? project_path(project.name) : home_path), notice: e.message}
			format.json {render :json => {error: e.message}, :status => :unprocessable_entity}
		end
	end


	def align
		begin
			if params[:annotations]
				annotations = params[:annotations]
			elsif params[:text].present?
				annotations = {:text => params[:text]}
				annotations[:denotations] = params[:denotations] if params[:denotations].present?
				annotations[:blocks] = params[:blocks] if params[:blocks].present?
				annotations[:relations] = params[:relations] if params[:relations].present?
				annotations[:attributes] = params[:attributes] if params[:attributes].present?
			else
				raise ArgumentError, t('controllers.annotations.create.no_annotation')
			end

			annotations[:sourcedb] = params[:sourcedb]
			annotations[:sourceid] = params[:sourceid]

			annotations = AnnotationUtils.normalize!(annotations)
			annotations_collection = [annotations]


		    doc = Doc.find_by(sourcedb: params[:sourcedb], sourceid: params[:sourceid]) \
		            || Doc.sequence_and_store_doc!(params[:sourcedb], params[:sourceid])

			m = AnnotationUtils.prepare_annotations!(annotations, doc)

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
			# ObtainDocAnnotationsJob.perform_now(project, doc.id, annotator, options.merge(debug: true))
			ObtainDocAnnotationsJob.perform_now(project, doc.id, annotator, options)
			"Annotations were successfully obtained."
		else
			# ObtainDocAnnotationsJob.perform_now(project, doc.id, annotator, options)
			# ObtainDocAnnotationsJob.perform_later(project, doc.id, annotator, options.merge(debug: true))
			ObtainDocAnnotationsJob.perform_later(project, doc.id, annotator, options)
			"A background job was created to obtain annotations."
		end

		respond_to do |format|
			format.html {redirect_back fallback_location: root_path, notice: message}
			format.json {}
		end
	rescue => e
		respond_to do |format|
			format.html {redirect_back fallback_location: root_path, notice: e.message}
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

			# ObtainAnnotationsJob.perform_now(project, docids_filepath, annotator, options)

			# ObtainAnnotationsJob.perform_later(project, docids_filepath, annotator, options.merge(debug: true))
			ObtainAnnotationsJob.perform_later(project, docids_filepath, annotator, options)

			project.update({annotator_id:annotator.id}) if annotator.persisted?

			messages << "The task 'Obtain annotations was created."
			message = messages.join("\n")

			respond_to do |format|
				format.html {redirect_back fallback_location: root_path, notice: message}
				format.json {}
			end
		rescue => e
			respond_to do |format|
				format.html {redirect_back fallback_location: root_path, notice: e.message}
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
				StoreAnnotationsCollectionUploadJob.perform_now(project, filepath, options)
				notice = "Annotations are successfully uploaded."
			else
				active_job = StoreAnnotationsCollectionUploadJob.perform_later(project, filepath, options)
				notice = "The task, '#{active_job.job_name}', is created."
			end

			respond_to do |format|
				format.html {redirect_back fallback_location: root_path, notice: notice}
				format.json {render json: {message: notice, task_location: project_job_url(project.name, task.id, format: :json)}, status: :ok}
			end
		rescue => e
			respond_to do |format|
				format.html {redirect_back fallback_location: root_path, notice: e.message}
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

					active_job = DeleteAnnotationsFromUploadJob.perform_later(project, filepath, options)
					notice = "The task, '#{active_job.job_name}', is created."
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
			format.html {redirect_back fallback_location: root_path, notice: notice}
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
		message = begin
			project = Project.editable(current_user).find_by! name: params[:project_id]

			source_project = Project.find_by name: params["select_project"]
			raise ArgumentError, "The project (#{params["select_project"]}) does not exist, or you are not authorized to access it.\n" unless source_project.present?
			raise ArgumentError, "You cannot import annotations from itself." if source_project == project
			raise ArgumentError, "The annotations in the project are blinded: #{name}." if source_project.accessibility == 3

			options = {mode: params[:mode]&.to_sym || :skip}
			raise ArgumentError, "The 'Merge' mode of importing annotations is disabled at the moment." if options[:mode] == :merge
			raise ArgumentError, "The 'Add' mode of importing annotations is disabled at the moment." if options[:mode] == :add

			ImportAnnotationsJob.perform_later(project, source_project.id, options)

			"The task, 'import annotations' (from the project, '#{source_project.name}') is created."
		rescue ActiveRecord::RecordNotFound => e
			raise "No project by the name exists under your management."
		rescue => e
			e.message
		end

		respond_to do |format|
			format.html {redirect_to project_path(project.name), notice: message}
		end
	end

	def analyse
		begin
			project = Project.editable(current_user).find_by_name(params[:project_id])
			raise "There is no such project in your management: #{params[:project_id]}." unless project.present?

			options = {mode: params[:mode].present? ? params[:mode] : 'merge'}

			AnalyseAnnotationsJob.perform_later(project, options)
			message = "The task, 'analyse project annotations: #{project.name}', is created."

		rescue => e
			messages = e.message
		end

		redirect_back fallback_location: project_path(project.name), notice: message
	end

	def remove_embeddings
		begin
			project = Project.editable(current_user).find_by_name(params[:project_id])
			raise "There is no such project in your management: #{params[:project_id]}." unless project.present?

			options = {mode: params[:mode].present? ? params[:mode] : 'merge'}

			RemoveEmbeddingsJob.perform_later(project, options)
			message = "The task, 'remove project embedded annotations: #{project.name}', is created."

		rescue => e
			messages = e.message
		end

		redirect_back fallback_location: project_path(project.name), notice: message
	end

	def remove_boundary_crossings
	end

	def remove_duplicate_labels
		begin
			project = Project.editable(current_user).find_by_name(params[:project_id])
			raise "There is no such project in your management: #{params[:project_id]}." unless project.present?

			options = {
									order:[
										"DiseaseOrPhenotypicFeature",
										"OrganismTaxon",
										"ChemicalEntity",
										"SequenceVariant",
										"CellLine",
										"GeneOrGeneProduct"
									]
								}

			RemoveDuplicateLabelsJob.perform_later(project, options)
			message = "The task, 'remove project duplicate labels: #{project.name}', is created."

		rescue => e
			messages = e.message
		end

		redirect_back fallback_location: project_path(project.name), notice: message
	end

	def create_project_annotations_tgz
		begin
			project = Project.editable(current_user).find_by_name(params[:project_id])
			raise "There is no such project in your management." unless project.present?

			# CreateAnnotationsTgzJob.perform_now(project, {})

			active_job = CreateAnnotationsTgzJob.perform_later(project, {})

			redirect_back fallback_location: root_path, notice: "The task '#{active_job.job_name}' is created."
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
			redirect_back fallback_location: root_path if status_error == false
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
				format.html {redirect_back fallback_location: root_path, notice: "annotations deleted"}
				format.json {render status: :no_content}
			end
		rescue => e
			redirect_back fallback_location: root_path, notice: e.message
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

		# a temporary solution to avoid rendering problem when there is a wrong typesetting
		@annotations.delete(:typesettings)

		AnnotationUtils.add_source_project_color_coding!(@annotations)

		respond_to do |format|
			format.html {render 'merge_view'}
			format.json {render json: @annotations}
		end
	end

	def annotations_list_view
		@span = params[:begin].present? ? {:begin => params[:begin].to_i, :end => params[:end].to_i} : nil
		@doc.set_ascii_body if params[:encoding] == 'ascii'

		option_full = params[:full].present?

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

		@annotations = @doc.hannotations(@visualize_projects, @span, context_size, is_full: option_full)
		@track_annotations = @annotations[:tracks]

		@track_annotations.each {|a| a[:text] = @annotations[:text]}

		respond_to do |format|
			format.html {render 'list_view'}
			format.json {render json: @annotations}
		end
	end
end
