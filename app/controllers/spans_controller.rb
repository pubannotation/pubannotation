class SpansController < ApplicationController

	def doc_spans_index
		begin
			docs = Doc.where(sourcedb:params[:sourcedb], sourceid:params[:sourceid])
			raise "Could not find the document." unless docs.present?
			raise "Multiple entries for #{params[:sourcedb]}:#{params[:sourceid]} found." if docs.length > 1

			@doc = docs.first

			@doc.set_ascii_body if params[:encoding] == 'ascii'
			@spans_index = @doc.spans_index

			respond_to do |format|
				format.html {render 'spans_index'}
				format.json {render json: {text: @doc.body, denotations: @spans_index}}
			end
		rescue => e
			respond_to do |format|
				format.html {redirect_to home_path, notice: e.message}
				format.json {render json: {notice:e.message}, status: :unprocessable_entity}
				format.txt  {render plain: message, status: :unprocessable_entity}
			end
		end
	end

	def project_doc_spans_index
		begin
			@project = Project.accessible(current_user).find_by_name(params[:project_id])
			raise "Could not find the project." unless @project.present?

			docs = @project.docs.where(sourcedb:params[:sourcedb], sourceid:params[:sourceid])
			raise "Could not find the document." unless docs.present?
			raise "Multiple entries for #{params[:sourcedb]}:#{params[:sourceid]} found." if docs.length > 1

			@doc = docs.first

			@doc.set_ascii_body if params[:encoding] == 'ascii'
			@spans_index = @doc.spans_index(@project.id)

			respond_to do |format|
				format.html {render 'spans_index'}
				format.json {render json: {text: @doc.body, denotations: @spans_index}}
			end
		rescue => e
			respond_to do |format|
				format.html {redirect_to project_docs_path(@project.name), notice: e.message}
				format.json {render json: {notice:e.message}, status: :unprocessable_entity}
				format.txt  {render plain: message, status: :unprocessable_entity}
			end
		end
	end
	
	def sql
		begin
			@search_path = spans_sql_path
			if params[:project_id].present?
				# when search from inner project
				project = Project.find_by_name(params[:project_id])
				if project.present?
					@search_path = project_spans_sql_path
				else
					redirect_to @search_path
				end
			end
			@denotations = Denotation.sql_find(params, current_user, project ||= nil)
			if @denotations.present?
				@denotations = @denotations.page(params[:page]).per(50)
			end
		rescue => error
			flash[:notice] = "#{t('controllers.shared.sql.invalid')} #{error}"
		end
	end

	def get_url
		doc = Doc.find_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
		unless doc.present?
			docs, messages = Doc.sequence_and_store_docs(params[:sourcedb], [params[:sourceid]])
			raise IOError, "Failed to get the document" unless docs.length == 1
			expire_fragment("sourcedb_counts")
			expire_fragment("count_#{params[:sourcedb]}")
			doc = docs.first
		end

		raise ArgumentError, "The 'text' parameter is missing." unless params[:text].present?
		raise ArgumentError, "The value of the 'text' parameter is not a string." unless params[:text].class == String

		text = params[:text].strip
		annotations = {
			text: text,
			sourcedb: params[:sourcedb],
			sourceid: params[:sourceid],
			denotations:[{span:{begin:0, end:text.length}, obj:'span'}]
		}

		m = Annotation.prepare_annotations!(annotations, doc)
		raise "Could not find the string in the specified document." if annotations.nil?

		url  = "#{home_url}/docs/sourcedb/#{annotations[:sourcedb]}/sourceid/#{annotations[:sourceid]}"

		span = annotations[:denotations].first[:span]
		url += "/spans/#{span[:begin]}-#{span[:end]}"

		respond_to do |format|
			format.any {render plain: url, status: :created, location: url}
		end
	rescue => e
		respond_to do |format|
			format.html {render plain: e.message, status: :unprocessable_entity}
			format.json {render json: {notice:e.message}, status: :unprocessable_entity}
			format.txt  {render plain: e.message, status: :unprocessable_entity}
		end
	end
end
