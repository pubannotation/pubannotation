class DestroyProjectJob < ApplicationJob
	include UseJobRecordConcern

	queue_as :general

	def perform(admin_project, project)
		prepare_progress_record(1)
		project.destroy!
		@job&.update_attribute(:num_dones, 1)
	end

	def job_name
		'Destroy project'
	end
end
