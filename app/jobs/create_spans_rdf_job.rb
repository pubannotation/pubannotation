class CreateSpansRdfJob < ApplicationJob
	include UseJobRecordConcern

	queue_as :low_priority

	def perform(project, in_collection, loc = nil)
		if @job
			prepare_progress_record(project.docs.count)
		end

		project.create_spans_RDF(in_collection, loc) do |i, doc, message|
			if @job
				@job.update_attribute(:num_dones, i + 1)
				if message.present?
					@job.add_message sourcedb: doc.sourcedb,
													 sourceid: doc.sourceid,
													 body: message
				end
				check_suspend_flag
			end
		end
	end

	def job_name
		"Create Spans RDF - #{resource_name}"
	end
end
