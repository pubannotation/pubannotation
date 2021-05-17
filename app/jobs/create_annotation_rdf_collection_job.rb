class CreateAnnotationRdfCollectionJob < Struct.new(:collection)
	include StateManagement

	def perform
		if @job
			@job.update_attribute(:num_items, collection.projects.indexable.count)
			@job.update_attribute(:num_dones, 0)
		end

		collection.create_annotations_RDF do |i, message|
			if @job
				@job.update_attribute(:num_dones, i + 1)
				@job.messages << Message.create({body: message}) if message
			end
		end
	end

end
