class CreateSpansRdfJob < ApplicationJob
	queue_as :low_priority

	def perform(project, in_collection)
		if @job
			prepare_progress_record(project.docs.count)
		end

		project.create_spans_RDF(in_collection) do |i, doc, message|
			if @job
				@job.update_attribute(:num_dones, i + 1)
				@job.messages << Message.create({sourcedb: doc.sourcedb, sourceid: doc.sourceid, body: message}) if message.present?
				check_suspend_flag
			end
		end
	end

	def job_name
		"Create Spans RDF - #{resource_name}"
	end
end
