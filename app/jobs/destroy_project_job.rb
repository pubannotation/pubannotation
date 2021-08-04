class DestroyProjectJob < ApplicationJob
	queue_as :general

	def perform(project)
		prepare_progress_record(3)

		project.jobs.each do |job|
			job.destroy_if_not_running
		end
		@job.update_attribute(:num_dones, 1)

		project.delete_docs if project.has_doc?
		@job.update_attribute(:num_dones, 2)

		project.destroy
		@job.update_attribute(:num_dones, 3)
	end

	def job_name
		'Destroy project'
	end

	private

	def organization_jobs
		Project.find_by_name('system-maintenance').jobs
	end
end
