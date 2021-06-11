class DestroyProjectJob < ApplicationJob
	queue_as :general

	def perform(project)
		@job.update_attribute(:num_items, 3)
		@job.update_attribute(:num_dones, 0)

		project.jobs.each do |job|
			job.destroy_if_not_running
		end
		@job.update_attribute(:num_dones, 1)

		project.delete_docs if project.has_doc?
		@job.update_attribute(:num_dones, 2)

		project.destroy
		@job.update_attribute(:num_dones, 3)
	end
end
