class StoreRdfizedSpansJob < Struct.new(:project, :rdfizer)
	include StateManagement

	def perform
    projects = Project.for_index
    docs = projects.inject([]){|sum, p| (sum + p.docs).uniq}
    annotations_collection = docs.collect{|doc| doc.hannotations}
		@job.update_attribute(:num_items, annotations_collection.length)
		@job.update_attribute(:num_dones, 0)
    annotations_collection.each_with_index do |annotations, i|
    	begin
        doc_ttl = project.get_conversion(annotations, rdfizer)
        project.post_rdf(doc_ttl, nil, i == 0)
	    rescue => e
 	      doc_description  = [annotations[:sourcedb], annotations[:sourceid], annotations[:divid]].compact.join('-')
				@job.messages << Message.create({item: "#{doc_description}", body: e.message})
			end
			@job.update_attribute(:num_dones, i + 1)
    end
	end
end
