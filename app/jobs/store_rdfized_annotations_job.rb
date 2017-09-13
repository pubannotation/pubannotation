require 'stardog'

class StoreRdfizedAnnotationsJob < Struct.new(:project, :filepath)
	include StateManagement
	include Stardog

	def perform
		count = %x{wc -l #{filepath}}.split.first.to_i

		@job.update_attribute(:num_items, count)
		@job.update_attribute(:num_dones, 0)

		sd = stardog(Rails.application.config.ep_url, user: Rails.application.config.ep_user, password: Rails.application.config.ep_password)
		db = Rails.application.config.ep_database
    graph_uri_project = project.graph_uri
    graph_uri_docs = Doc.graph_uri

    sd.clear_db(db, graph_uri_project)

		File.foreach(filepath).with_index do |docid, i|
			docid.chomp!.strip!
			doc = Doc.find(docid)
    	begin
    		num_denotations = doc.denotations.where("denotations.project_id = ?", project.id).count

    		if num_denotations > 0
	    		hannotations = doc.hannotations(project)
	        doc_ttl = project.get_conversion(hannotations, Rails.application.config.rdfizer_annotations)
			    sd.add("PubAnnotation", doc_ttl, graph_uri_project, "text/turtle")

			    doc_last_indexed_at = doc.last_indexed_at(sd)
		      num_spans_new = doc_last_indexed_at.nil? ? num_denotations : doc.denotations.where("denotations.project_id = ? AND denotations.updated_at > ?", project.id, doc_last_indexed_at).count

		      if num_spans_new > 0
			    	graph_uri_doc = doc.graph_uri
				    sd.clear_db(db, graph_uri_doc)
		    		hannotations = doc.hannotations
		        doc_ttl = project.get_conversion(hannotations, Rails.application.config.rdfizer_spans)
				    sd.add("PubAnnotation", doc_ttl, graph_uri_doc, "text/turtle")
				    update_time(sd, db, graph_uri_doc)
				  end
	      end
	    rescue => e
				doc_description  = [doc.sourcedb, doc.sourceid, doc.serial].compact.join('-')
				puts "[error] #{e}"
				@job.messages << Message.create({sourcedb: doc.sourcedb, sourceid: doc.sourceid, divid: doc.serial, body: e.message})
			end
			@job.update_attribute(:num_dones, i + 1)
    end

    update_time(sd, db, graph_uri_project)

    File.unlink(filepath)
	end

	private

	def update_time(sd, database, graph_uri)
    update = <<-HEREDOC
    	DELETE {<#{graph_uri}> <http://www.w3.org/ns/prov#generatedAtTime> ?generationTime .}
    	WHERE {<#{graph_uri}> <http://www.w3.org/ns/prov#generatedAtTime> ?generationTime .}
    HEREDOC
    sd.update(database, update)

    statement = %|<#{graph_uri}> <http://www.w3.org/ns/prov#generatedAtTime> "#{DateTime.now.iso8601}"^^xsd:dateTime .|
	  sd.add(database, statement, nil, "text/turtle")
	end
end
