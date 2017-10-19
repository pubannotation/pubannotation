class SearchController < ApplicationController
	def index
		@project = if params.has_key? :project_name
			p = Project.accessible(current_user).find_by_name(params[:project_name])
			raise "Could not find the project: #{params[:project_name]}." unless p.present?
			p
		end

		query = params[:query]
		@page = params[:page].to_i if params.has_key?(:page)
		@page_size = params.has_key?(:page_size) ? params[:page_size].to_i : 1
		@solutions, @message = get_solutions(query, @page, @page_size) if query.present?
		@num_solutions = if params.has_key?(:num_solutions)
			params[:num_solutions].to_i
		elsif @solutions
			@solutions["results"]["bindings"].length
		end

		rendering = begin
			r = params[:show_mode] == "textae" ? :search_in_textae : :search_in_raw
			if @solutions && @num_solutions > 0 && r == :search_in_textae

				# check whether solutions include spans
				s = @solutions["results"]["bindings"].first
				spans = s.values.select{|v| span?(v["value"])}.map{|v| v["value"]}
				raise ArgumentError, "The results do not include a span, thus cannot be rendered in TextAE." if spans.empty?

				# check whether spans in one solutions come from the same documents
				span_prefixes = spans.map{|s| span_prefix(s)}.uniq
				raise ArgumentError, "The results include spans from different docs, thus cannot be rendered in TextAE." if span_prefixes.length > 1

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
		results = sd.query(db, query)
		results.success? ? [results.body.to_h, nil] : [nil, JSON.parse(results.body, symbolize_names:true)]
	end

	def span?(v)
		!!(%r|/spans/\d+-\d+$|.match(v))
	end

	def span_prefix(span_url)
		span_url[0 .. span_url.rindex('/')]
	end
end
