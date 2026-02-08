class CreateAnnotationsRdfJob < ApplicationJob
	include UseJobRecordConcern

	PROGRESS_UPDATE_INTERVAL = 10

	queue_as :low_priority

	def perform(project, doc_ids = nil, loc = nil)
		num_docs = doc_ids.nil? ? project.docs.count : doc_ids.count
		if @job
			prepare_progress_record(num_docs)
		end

		project.create_annotations_RDF(doc_ids, loc) do |i, doc, message|
			if @job
				if (i + 1) % PROGRESS_UPDATE_INTERVAL == 0 || (i + 1) == num_docs
					@job.update_attribute(:num_dones, i + 1)
				end
				if message
					@job.add_message sourcedb: doc.sourcedb,
													 sourceid: doc.sourceid,
													 body: message
				end
				check_suspend_flag
			end
		end
	end

	def job_name
		"Create Annotation RDF - #{resource_name}"
	end
end
