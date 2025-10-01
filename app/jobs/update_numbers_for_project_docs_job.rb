class UpdateNumbersForProjectDocsJob < ApplicationJob
	queue_as :low_priority

	def perform(project)
		prepare_progress_record(2)

		Doc.update_numbers(project)
		@job&.update_attribute(:num_dones, 1)

		project.docs_stat_update
		@job&.update_attribute(:num_dones, 2)
	end

	def job_name
		"Update numbers for documents in project"
	end
end
