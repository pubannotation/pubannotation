class DeleteAllDocsFromProjectJob < ApplicationJob
	include UseJobRecordConcern

	queue_as :general

	def perform(project)
		prepare_progress_record(1)

		project.delete_docs

		# UpdateElasticsearchIndexJob.perform_later(project)

		@job&.update_attribute(:num_dones, 1)
	end

	def job_name
		'Delete all docs'
	end
end
