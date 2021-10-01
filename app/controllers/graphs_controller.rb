class GraphsController < ApplicationController
	before_action :set_organization, only: [:show]

	def show
		@organization_path = get_organization_path
		@sparql_ep = get_sparql_ep

		query = params[:query]
		@page = params[:page].to_i if params.has_key?(:page)
		@page_size = params.has_key?(:page_size) ? params[:page_size].to_i : 10

		@solutions = @message = nil

		if query.present?
			begin
				@solutions = Graph.sparql_protocol_query_operation_get(@sparql_ep, query)
			rescue => e
				@message = e.message
			end

			@num_solutions = if params.has_key?(:num_solutions)
				params[:num_solutions].to_i
			elsif @solutions
				@solutions[:results][:bindings].length
			end
		end

		rendering = begin
			r = params[:show_mode] == "textae" ? :search_in_textae : :search_in_raw
			if @solutions && @num_solutions > 0 && r == :search_in_textae
				raise ArgumentError, "For the results to be rendered in TextAE, at least one project needs to be selected." unless params[:projects].present?

				# check whether solutions include spans
				s = @solutions[:results][:bindings].first
				spans = s.values.select{|v| span?(v["value"])}.map{|v| v["value"]}
				raise ArgumentError, "Because the results do not include a span, they are shown in table instead rendered in TextAE." if spans.empty?

				# check whether spans in one solutions come from the same documents
				span_prefixes = spans.map{|s| span_prefix(s)}.uniq
				raise ArgumentError, "Because the results include spans from different docs, they are shown in table instead rendered in TextAE." if span_prefixes.length > 1

				# check whether paging is necessary
				if @page.nil? && @num_solutions > @page_size
					params[:page_size] = @page_size
					params[:page] = 1
					@page = 1
					params[:num_solutions] = @num_solutions
					@solutions, @message = get_solutions(query, 1, @page_size)
				end
			end
			r
		rescue => e
			flash[:notice] = e.message
			params[:show_mode] = "raw"
			:search_in_raw
		end

		params.delete(:template_select)

    respond_to do |format|
      format.html { render rendering }
      format.json { render json: @solutions }
    end
	end

	protected

	def get_solutions(query, page = nil, page_size = nil)
		if page
			query = query + "\nLIMIT #{page_size}\nOFFSET #{(page - 1) * page_size}"
		end

		sd = Pubann::Application.config.sd
		db = Pubann::Application.config.db

		begin
			results = sd.query(db, query, {reasoning: reasoning})
		rescue => e
			return [nil, {message: e.message}]
		end

		if results.success?
			[results.body.to_h, nil]
		else
			case results.status
			when 408, 504
				[nil, {message: "Request timeout (#{results.status}): you are advised to re-try with a more specific query."}]
			when 502, 503
				[nil, {message: "SPARQL endpoint unavailable (#{results.status}): please re-try after a few minutes, or contact the system administrator if the problem lasts long."}]
			else
				begin
					[nil, JSON.parse(results.body, symbolize_names:true)]
				rescue
					[nil, {message:results.body + "\n#{results.status}"}]
				end
			end
		end
	end


	def get_solutions_sd(query, reasoning, page = nil, page_size = nil)
		if page
			query = query + "\nLIMIT #{page_size}\nOFFSET #{(page - 1) * page_size}"
		end

		sd = Pubann::Application.config.sd
		db = Pubann::Application.config.db

		begin
			results = sd.query(db, query, {reasoning: reasoning})
		rescue => e
			return [nil, {message: e.message}]
		end

		if results.success?
			[results.body.to_h, nil]
		else
			case results.status
			when 408, 504
				[nil, {message: "Request timeout (#{results.status}): you are advised to re-try with a more specific query."}]
			when 502, 503
				[nil, {message: "SPARQL endpoint unavailable (#{results.status}): please re-try after a few minutes, or contact the system administrator if the problem lasts long."}]
			else
				begin
					[nil, JSON.parse(results.body, symbolize_names:true)]
				rescue
					[nil, {message:results.body + "\n#{results.status}"}]
				end
			end
		end
	end

	def span?(v)
		!!(%r|/spans/\d+-\d+$|.match(v))
	end

	def span_prefix(span_url)
		span_url[0 .. span_url.rindex('/')]
	end

	def set_organization
		if params[:project_name].present?
			@organization = Project.accessible(current_user).find_by_name(params[:project_name])
			raise "Could not find the project." unless @organization.present?
		elsif params[:collection_name].present?
			@organization = Collection.accessible(current_user).find_by_name(params[:collection_name])
			raise "Could not find the collection." unless @organization.present?
		else
			@organization = nil
		end
	end

	def get_sparql_ep
		(@organization && @organization.sparql_ep.present?) ? @organization.sparql_ep : Pubann::Application.config.ep_url
	end

	def get_organization_path
		if params.has_key? :project_name
			project_path(params[:project_name])
		elsif params.has_key? :collection_name
			collection_path(params[:collection_name])
		end
	end

end
