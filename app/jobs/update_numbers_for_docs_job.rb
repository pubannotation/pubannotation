class UpdateNumbersForDocsJob < ApplicationJob
	include UseJobRecordConcern

	queue_as :low_priority

	def perform(admin_project)
		prepare_progress_record(2)

		Doc.update_numbers
		@job&.update_attribute(:num_dones, 1)

		Project.all.each{|project| project.docs_stat_update}
		@job&.update_attribute(:num_dones, 2)
	end

	def job_name
		"Update numbers for each document"
	end
end
