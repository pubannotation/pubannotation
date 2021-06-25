class DeleteAllDocsFromProjectJob < ApplicationJob
	queue_as :general

	def perform(project)
		@job.update_attribute(:num_items, 1) if @job
		@job.update_attribute(:num_dones, 0) if @job

		project.delete_docs

		active_job = UpdateElasticsearchIndexJob.perform_later(project)
		active_job.create_job_record(project.jobs, 'Update text search index')

		@job.update_attribute(:num_dones, 1) if @job
		ActionController::Base.new.expire_fragment("sourcedb_counts_#{project.name}")
		ActionController::Base.new.expire_fragment("count_docs_#{project.name}")
	end
end
