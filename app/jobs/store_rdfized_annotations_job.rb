class StoreRdfizedAnnotationsJob < Struct.new(:sproject, :project, :rdfizer)
	include StateManagement

	def perform
		graph_name = project.name
		@job.update_attribute(:num_items, project.docs.count)
		@job.update_attribute(:num_dones, 0)
    project.docs.each_with_index do |doc, i|
    	begin
	      num = doc.denotations.where("denotations.project_id = ?", project.id).count
	      if num > 0
	    		annotations = doc.hannotations(project)
	        doc_ttl = sproject.get_conversion(doc.hannotations(project), rdfizer)
	        sproject.post_rdf(doc_ttl, graph_name, i == 0)
	      end
	    rescue => e
 	      doc_description  = [doc.sourcedb, doc.sourceid, doc.serial].compact.join('-')
				@job.messages << Message.create({sourcedb: doc.sourcedb, sourceid: doc.sourceid, divid: doc.serial, body: e.message})
			end
			@job.update_attribute(:num_dones, i + 1)
    end
	end
end
