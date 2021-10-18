class GraphsController < ApplicationController
	before_action :set_organization, only: [:show]

	def show
		@organization_path = get_organization_path
		@sparql_ep = get_sparql_ep

		query = params[:query]
		if params[:show_mode] == "textae"
			@page = params.has_key?(:page) ? params[:page].to_i : 1
			@page_size = params.has_key?(:page_size) ? params[:page_size].to_i : 10
		end

		@solutions = @bindings = @message = nil
		@more_solutions = false

		if query.present?
			begin
				@solutions = Graph.sparql_protocol_query_operation_get(@sparql_ep, query, nil, nil, @page, @page_size)
				if @page_size && @solutions[:results][:bindings].length > @page_size
					@more_solutions = true
					@solutions[:results][:bindings].slice!(@page_size .. -1)
				end
				@bindings = @solutions[:results][:bindings]
			rescue => e
				@message = e.message
			end
		end

		rendering = begin
			r = params[:show_mode] == "textae" ? :search_in_textae : :search_in_raw
			if @solutions && @bindings.length > 0 && r == :search_in_textae
				raise ArgumentError, "For the results to be rendered in TextAE, at least one project needs to be selected." unless params[:projects].present?

				# check whether solutions include spans
				s = @bindings.first
				spans = s.values.select{|v| span?(v[:value])}.map{|v| v[:value]}
				raise ArgumentError, "Because the results do not include a span, they are shown in table instead rendered in TextAE." if spans.empty?

				# check whether spans in one solutions come from the same documents
				span_prefixes = spans.map{|s| span_prefix(s)}.uniq
				raise ArgumentError, "Because the results include spans from different docs, they are shown in table instead rendered in TextAE." if span_prefixes.length > 1
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
