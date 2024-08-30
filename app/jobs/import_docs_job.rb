class ImportDocsJob < ApplicationJob
	include UseJobRecordConcern

	queue_as :general

	def perform(project, source_project_id)
		prepare_progress_record(1)

		count = project.import_docs_from_another_project(source_project_id)

		@job&.add_message body: "#{count} doc(s) were imported."
		@job&.update_attribute(:num_dones, 1)
	end

	def job_name
		'Import docs'
	end
end
