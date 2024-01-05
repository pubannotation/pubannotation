class CreateSpansRdfCollectionJob < ApplicationJob
	include UseJobRecordConcern

	queue_as :low_priority

	def perform(collection, loc)
		if @job
			prepare_progress_record(collection.primary_docids.count)
		end

		collection.create_spans_RDF(loc) do |i, doc, message|
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
		"Create Spans RDF Collection- #{resource_name}"
	end
end
