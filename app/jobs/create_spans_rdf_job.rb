class CreateSpansRdfJob < Struct.new(:project)
	include StateManagement

	def perform
		if @job
			@job.update_attribute(:num_items, project.docs.count)
			@job.update_attribute(:num_dones, 0)
		end

		project.create_spans_RDF do |i, doc, message|
			if @job
				@job.update_attribute(:num_dones, i + 1)
				@job.messages << Message.create({sourcedb: doc.sourcedb, sourceid: doc.sourceid, body: message}) if message.present?
			end
		end
	end

end
