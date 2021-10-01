class MessagesController < ApplicationController
	before_action :authenticate_user!

	def index
		@project = Project.editable(current_user).find_by_name(params[:project_id])
		raise "There is no such project in your management." unless @project.present?

		@job = Job.find(params[:id])
		@messages = @job.messages.order(:created_at)

		respond_to do |format|
			format.html
			format.json {render json: @messages.to_json(:only => [:sourcedb, :sourceid, :body, :created_at])}
			format.tsv  {render plain: @messages.as_tsv}
		end
	end

	def show
		@message = Message.find(params[:id])
		@job = @message.job
		@organization = @message.job.organization
	end

	def data_source
		message = Message.find(params[:id])

		source_text = message.data[:block_alignment][:text]
		denotations = message.data[:block_alignment][:denotations]

		data = {text: source_text}
		data[:denotations] = denotations if denotations.present?

		send_data data.to_json, filename: "#{message.sourcedb}-#{message.sourceid}-annotations.json"
	end

	def data_target
		message = Message.find(params[:id])

		target = message.data[:block_alignment][:reference_text]

		data = {text: target}

		send_data data.to_json, filename: "#{message.sourcedb}-#{message.sourceid}.json"
	end

end
