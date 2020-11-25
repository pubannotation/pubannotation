class DivsController < ApplicationController
	include ApplicationHelper
	include AnnotationsHelper

	def index
		begin
			@divs = Doc.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid], order: :serial)
			raise "There is no such document." unless @divs.present?

			@divs_count = @divs.count
			@doc = @divs.first

			htexts = nil
			if params[:keywords].present?
				search_results = Doc.search_docs({body: params[:keywords].strip.downcase, sourcedb: params[:sourcedb], sourceid: params[:sourceid], page:params[:page], per:params[:per]})
				@search_count = search_results.results.total
				htexts = search_results.results.map{|r| {text: r.highlight.body}}
				@divs = @search_count > 0 ? search_results.records : []
			end

			@divs.each{|div| div.set_ascii_body} if (params[:encoding] == 'ascii')

			respond_to do |format|
				format.html {
					if htexts
						htexts = htexts.map{|h| h[:text].first}
						@divs = @divs.zip(htexts).each{|d,t| d.body = t}.map{|d,t| d}
					end
				}
				format.json {
					hdocs = @divs.map{|d| d.to_list_hash('doc')}
					if htexts
						hdocs = hdocs.zip(htexts).map{|d| d.reduce(:merge)}
					end
					render json: hdocs
				}
				format.tsv  {
					hdocs = @divs.map{|d| d.to_list_hash('doc')}
					if htexts
						htexts.each{|h| h[:text] = h[:text].first}
						hdocs = hdocs.zip(htexts).map{|d| d.reduce(:merge)}
					end
					render text: Doc.hash_to_tsv(hdocs)
				}
				format.txt  {redirect_to doc_sourcedb_sourceid_show_path(params[:project_id], params[:sourcedb], params[:sourceid], format: :txt)}
			end
		rescue => e
			respond_to do |format|
				format.html {redirect_to home_path, notice: e.message}
				format.json {render json: {notice:e.message}, status: :unprocessable_entity}
				format.txt  {render status: :unprocessable_entity}
			end
		end
	end

	def index_in_project
		begin
			@project = Project.accessible(current_user).find_by_name(params[:project_id])
			raise "There is no such project." unless @project.present?

			@divs = @project.docs.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid], order: :serial)
			raise "There is no such document in the project." unless @divs.present?

			@divs_count = @divs.count
			@doc = @divs.first

			htexts = nil
			if params[:keywords].present?
				search_results = Doc.search_docs({body: params[:keywords].strip.downcase, project_id: @project.id, sourcedb: params[:sourcedb], sourceid: params[:sourceid], page:params[:page], per:params[:per]})
				@search_count = search_results.results.total
				htexts = search_results.results.map{|r| {text: r.highlight.body}}
				@divs = @search_count > 0 ? search_results.records : []
			end

			@divs.each{|div| div.set_ascii_body} if (params[:encoding] == 'ascii')

			respond_to do |format|
				format.html {
					if htexts
						htexts = htexts.map{|h| h[:text].first}
						@divs = @divs.zip(htexts).each{|d,t| d.body = t}.map{|d,t| d}
					end
				}
				format.json {
					hdocs = @divs.map{|d| d.to_list_hash('doc')}
					if htexts
						hdocs = hdocs.zip(htexts).map{|d| d.reduce(:merge)}
					end
					render json: hdocs
				}
				format.tsv  {
					hdocs = @divs.map{|d| d.to_list_hash('doc')}
					if htexts
						htexts.each{|h| h[:text] = h[:text].first}
						hdocs = hdocs.zip(htexts).map{|d| d.reduce(:merge)}
					end
					render text: Doc.hash_to_tsv(hdocs)
				}
				format.txt  {redirect_to doc_sourcedb_sourceid_show_path(params[:project_id], params[:sourcedb], params[:sourceid], format: :txt)}
			end
		rescue => e
			respond_to do |format|
				format.html {redirect_to (@project.present? ? project_docs_path(@project.name) : home_path), notice: e.message}
				format.json {render json: {notice:e.message}, status: :unprocessable_entity}
				format.txt  {render status: :unprocessable_entity}
			end
		end
	end

	# GET /docs/sourcedb/:sourcedb/sourceid/:sourceid/divs/:divid
	def show
		# TODO compatibility for PMC and Docs
		# params[:divid] ||= params[:id]
		begin
			@doc = Doc.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:divid])
			raise "There is no such document." unless @doc.present?

			@doc.set_ascii_body if (params[:encoding] == 'ascii')
			@content = @doc.body.gsub(/\n/, "<br>")

			get_docs_projects

			@annotations = @doc.hannotations(@projects.select{|p|p.annotations_accessible?(current_user)})
			if @annotations[:tracks].present?
				@annotations[:denotations] = @annotations[:tracks].inject([]){|denotations, track| denotations += (track[:denotations] || [])}
				@annotations[:relations] = @annotations[:tracks].inject([]){|relations, track| relations += (track[:relations] || [])}
				@annotations[:modifications] = @annotations[:tracks].inject([]){|modifications, track| modifications += (track[:modifications] || [])}
			end

			serial = params[:divid].to_i
			divs_count = Doc.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid]).count
			@prev_path = serial > 0 ? doc_sourcedb_sourceid_divs_show_path(params[:sourcedb], params[:sourceid], serial - 1) : nil
			@next_path = serial < divs_count - 1 ? doc_sourcedb_sourceid_divs_show_path(params[:sourcedb], params[:sourceid], serial + 1) : nil

			respond_to do |format|
				format.html {render 'docs/show'}
				format.json {render json: @doc.to_hash}
				format.txt  {render text: @doc.body}
			end

		rescue => e
			respond_to do |format|
				format.html {redirect_to home_path, notice: e.message}
				format.json {render json: {notice:e.message}, status: :unprocessable_entity}
				format.txt  {render status: :unprocessable_entity}
			end
		end
	end

	def show_in_project
		begin
			@project = Project.accessible(current_user).find_by_name(params[:project_id])
			raise "There is no such project." unless @project.present?

			@doc = @project.docs.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:divid])
			raise "There is no such document in the project." unless @doc.present?

			@doc.set_ascii_body if (params[:encoding] == 'ascii')
			@content = @doc.body.gsub(/\n/, "<br>")
			@annotations = @doc.hannotations(@project)

			serial = params[:divid].to_i
			divs_count = Doc.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid]).count
			@prev_path = serial > 0 ? show_project_sourcedb_sourceid_divs_docs_path(params[:project_id], params[:sourcedb], params[:sourceid], serial - 1) : nil
			@next_path = serial < divs_count - 1 ? show_project_sourcedb_sourceid_divs_docs_path(params[:project_id], params[:sourcedb], params[:sourceid], serial + 1) : nil

			respond_to do |format|
				format.html {render 'docs/show_in_project'}
				format.json {render json: @doc.to_hash}
				format.txt  {render text: @doc.body}
			end

		rescue => e
			respond_to do |format|
				format.html {redirect_to (@project.present? ? project_docs_path(@project.name) : home_path), notice: e.message}
				format.json {render json: {notice:e.message}, status: :unprocessable_entity}
				format.txt  {render status: :unprocessable_entity}
			end
		end
	end
end
