class MessagesController < ApplicationController
	before_filter :authenticate_user!

	def index
		@project = Project.editable(current_user).find_by_name(params[:project_id])
		raise "There is no such project in your management." unless @project.present?

		@job = Job.find(params[:id])
		@messages = @job.messages.order(:created_at)

		respond_to do |format|
			format.html
			format.json {render json: @messages.to_json(:only => [:sourcedb, :sourceid, :body, :created_at])}
			format.tsv  {render text: @messages.as_tsv}
		end
	end

	def show
		@message = Message.find(params[:id])
		@project = @message.job.project
	end
end
