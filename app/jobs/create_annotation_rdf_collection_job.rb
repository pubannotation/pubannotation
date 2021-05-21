class CreateAnnotationRdfCollectionJob < Struct.new(:collection, :options)
	include StateManagement

	def perform
		if @job
			@job.update_attribute(:num_items, collection.projects.indexable.count + 1)
			@job.update_attribute(:num_dones, 0)
		end

		collection.create_annotations_RDF(forced?) do |i, message|
			if @job
				@job.increment!(:num_dones, 1)
				@job.messages << Message.create({body: message}) if message
			end
		end

		collection.create_spans_RDF
		@job.increment!(:num_dones, 1) if @job
	end

	def forced?
		options && options.has_key?(:forced) ? options[:forced] == true : false
	end

end
