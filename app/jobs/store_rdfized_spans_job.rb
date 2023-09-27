class StoreRdfizedSpansJob < ApplicationJob
	queue_as :low_priority

	def perform(sproject, docids, rdfizer)
		if @job
			prepare_progress_record(docids.length)
		end
		docids.each_with_index do |docid, i|
			begin
				doc = Doc.find(docid)
				annotations = doc.hannotations(nil, nil, nil)
				doc_ttl = sproject.get_conversion(annotations, rdfizer)
				sproject.post_rdf(doc_ttl, nil, i == 0)
			rescue => e
				if @job
					@job.add_message sourcedb: annotations[:sourcedb],
													 sourceid: annotations[:sourceid],
													 divid: annotations[:divid],
													 body: e.message
				else
					raise ArgumentError, message
				end
			ensure
				if @job
					@job.update_attribute(:num_dones, i + 1)
					check_suspend_flag
				end
			end
		end
	end

	def job_name
		"Store RDFized spans for selected projects"
	end
end
