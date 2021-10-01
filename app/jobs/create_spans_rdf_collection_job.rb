class CreateSpansRdfCollectionJob < ApplicationJob
	queue_as :low_priority

	def perform(collection)
		project_ids = collection.primary_projects.pluck(:id)
		doc_ids = [].union(*collection.primary_projects.collect{|project| project.docs.pluck(:id)})

		if @job
			prepare_progress_record(doc_ids.count)
		end

		File.open(collection.spans_trig_filepath, "w") do |f|
			doc_ids.each_with_index do |doc_id, i|
				doc = Doc.find(doc_id)

				doc_spans_trig = if i == 0
					doc.get_spans_rdf(project_ids, {with_prefixes: true})
				else
					doc.get_spans_rdf(project_ids, {with_prefixes: false})
				end

				f.write("\n") unless i == 0
				f.write(doc_spans_trig)
			rescue => e
				if @job
					@job.messages << Message.create({sourcedb: doc.sourcedb, sourceid: doc.sourceid, body: e.message}) if message.present?
				else
					raise e
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
		"Create Spans RDF Collection- #{resource_name}"
	end
end
