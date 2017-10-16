class SearchController < ApplicationController
	def index
		@project = if params.has_key? :project_name
			p = Project.accessible(current_user).find_by_name(params[:project_name])
			raise "Could not find the project: #{params[:project_name]}." unless p.present?
			p
		end

		query = params[:query]
		@solutions, @message = if query.present?
			sd = Pubann::Application.config.sd
			db = Pubann::Application.config.db
			results = sd.query(db, query)
			results.success? ? [results.body.to_h, nil] : [nil, JSON.parse(results.body, symbolize_names:true)]
		end

		rendering = begin
			r = params[:show_mode] == "textae" ? :search_in_textae : :search_in_raw
			if @solutions && r == :search_in_textae
				s = @solutions["results"]["bindings"].first
				spans = s.values.select{|v| span?(v["value"])}.map{|v| v["value"]}
				raise ArgumentError, "The results do not include a span, thus cannot be rendered in TextAE." if spans.empty?
				span_prefixes = spans.map{|s| span_prefix(s)}.uniq
				raise ArgumentError, "The results include spans from different docs, thus cannot be rendered in TextAE." if span_prefixes.length > 1
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

	def span?(v)
		!!(%r|/spans/\d+-\d+$|.match(v))
	end

	def span_prefix(span_url)
		span_url[0 .. span_url.rindex('/')]
	end
end
