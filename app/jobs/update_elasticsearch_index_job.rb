class UpdateElasticsearchIndexJob < ApplicationJob
	queue_as :general

	def perform(project)
		if @job
			prepare_progress_record(1)
		end
		project.update_es_index
		@job.update_attribute(:num_dones, 1) if @job
	end

	def job_name
		'Update text search index'
	end
end
