class UpdateNumbersForProjectDocsJob < ApplicationJob
	include UseJobRecordConcern

	queue_as :low_priority

	def perform(project)
		prepare_progress_record(2)

		doc_ids = project.docs.pluck(:id)
		if doc_ids.any?
			DocumentAnnotationCounter.bulk_update_docs_counts(doc_ids)
			ProjectDoc.bulk_update_counts(project_id: project.id)
		end
		@job&.update_attribute(:num_dones, 1)

		project.docs_stat_update
		@job&.update_attribute(:num_dones, 2)
	end

	def job_name
		"Update numbers for documents in project"
	end
end
