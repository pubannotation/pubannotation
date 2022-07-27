class CreateAnnotationsRdfJob < ApplicationJob
	queue_as :low_priority

	def perform(project, doc_ids = nil, loc = nil)
		if @job
			prepare_progress_record(doc_ids.nil? ? project.docs.count : doc_ids.count)
		end

		project.create_annotations_RDF(doc_ids, loc) do |i, doc, message|
			if @job
				@job.update_attribute(:num_dones, i + 1)
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
