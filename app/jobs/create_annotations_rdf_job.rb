class CreateAnnotationsRdfJob < ApplicationJob
	queue_as :low_priority

	def perform(project, doc_ids = nil)
		if @job
			prepare_progress_record(project.docs.count)
		end

		project.create_annotations_RDF(doc_ids) do |i, doc, message|
			if @job
				@job.update_attribute(:num_dones, i + 1)
				@job.messages << Message.create({sourcedb: doc.sourcedb, sourceid: doc.sourceid, body: message}) if message
				check_suspend_flag
			end
		end
	end

	def job_name
		"Create Annotation RDF - #{resource_name}"
	end
end
