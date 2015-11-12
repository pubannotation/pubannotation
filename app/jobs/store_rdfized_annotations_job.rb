class StoreRdfizedAnnotationsJob < Struct.new(:project, :collection, :rdfizer, :graph_name)
	include StateManagement

	def perform
		@job.update_attribute(:num_items, collection.length)
		@job.update_attribute(:num_dones, 0)
    collection.each_with_index do |annotations, i|
    	begin
        doc_ttl = project.get_conversion(annotations, rdfizer)
        project.post_rdf(doc_ttl, graph_name, i == 0)
	    rescue => e
 	      doc_description  = [annotations[:sourcedb], annotations[:sourceid], annotations[:divid]].compact.join('-')
				@job.messages << Message.create({item: "#{doc_description}", body: e.message})
			end
			@job.update_attribute(:num_dones, i + 1)
    end
	end
end
