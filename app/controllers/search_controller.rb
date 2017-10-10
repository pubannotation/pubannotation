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

		rendering = params[:show_mode] == "textae" ? :search_in_textae : :search_in_raw

    respond_to do |format|
      format.html { render rendering}
      format.json { render json: @solutions }
    end
	end
end
