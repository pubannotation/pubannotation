class DeleteAllAnnotationsFromProjectJob < ApplicationJob
	include UseJobRecordConcern

	queue_as :general

	def perform(project)
		prepare_progress_record(1)
		begin
			project.delete_annotations
		rescue => e
			@job&.add_message body: e.message
		end
		@job&.update_attribute(:num_dones, 1)
		project.update_attribute(:annotations_count, 0)
	end

	def job_name
		'Delete all annotations in project'
	end
end
