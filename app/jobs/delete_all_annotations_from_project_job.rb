class DeleteAllAnnotationsFromProjectJob < ApplicationJob
	queue_as :general

	def perform(project)
		docs = project.docs
		prepare_progress_record(1)
		begin
			project.delete_annotations
		rescue => e
			@job.messages << Message.create({body: e.message})
		end
		@job.update_attribute(:num_dones, 1)
		project.update_attribute(:annotations_count, 0)
	end

	def job_name
		'Delete all annotations in project'
	end
end
