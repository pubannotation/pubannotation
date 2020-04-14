class StoreRdfizedSpansJob < Struct.new(:sproject, :docids, :rdfizer)
	include StateManagement

	def perform
		if @job
			@job.update_attribute(:num_items, docids.length)
			@job.update_attribute(:num_dones, 0)
		end
    docids.each_with_index do |docid, i|
    	begin
    		doc = Doc.find(docid)
    		annotations = doc.hannotations
        doc_ttl = sproject.get_conversion(annotations, rdfizer)
        sproject.post_rdf(doc_ttl, nil, i == 0)
	    rescue => e
				if @job
					@job.messages << Message.create({sourcedb: annotations[:sourcedb], sourceid: annotations[:sourceid], divid: annotations[:divid], body: e.message})
				else
					raise ArgumentError, message
				end
			ensure
				@job.update_attribute(:num_dones, i + 1) if @job
			end
    end
	end
end
