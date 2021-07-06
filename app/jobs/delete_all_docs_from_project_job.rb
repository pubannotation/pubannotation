class DeleteAllDocsFromProjectJob < ApplicationJob
	queue_as :general

	def perform(project)
		if @job
			prepare_progress_record(1)
		end

		project.delete_docs

		active_job = UpdateElasticsearchIndexJob.perform_later(project)
		active_job.create_job_record(project.jobs, 'Update text search index')

		@job.update_attribute(:num_dones, 1) if @job
		ActionController::Base.new.expire_fragment("sourcedb_counts_#{project.name}")
		ActionController::Base.new.expire_fragment("count_docs_#{project.name}")
	end

	def job_name
		'Delete all docs'
	end
end
