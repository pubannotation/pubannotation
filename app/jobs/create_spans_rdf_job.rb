class CreateSpansRdfJob < ApplicationJob
	queue_as :low_priority

	def perform(project, in_collection)
		if @job
			@job.update_attribute(:num_items, project.docs.count)
			@job.update_attribute(:num_dones, 0)
		end

		project.create_spans_RDF(in_collection) do |i, doc, message|
			if @job
				@job.update_attribute(:num_dones, i + 1)
				@job.messages << Message.create({sourcedb: doc.sourcedb, sourceid: doc.sourceid, body: message}) if message.present?
			end
		end
	end
end
