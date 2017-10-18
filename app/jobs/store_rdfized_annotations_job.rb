require 'stardog'

class StoreRdfizedAnnotationsJob < Struct.new(:project, :filepath)
	include StateManagement
	include Stardog

	def perform
		size_batch_annotations = 2000
		size_batch_spans = 1000
		count = %x{wc -l #{filepath}}.split.first.to_i

		@job.update_attribute(:num_items, count)
		@job.update_attribute(:num_dones, 0)

		sd = stardog(Rails.application.config.ep_url, user: Rails.application.config.ep_user, password: Rails.application.config.ep_password)
		db = Rails.application.config.ep_database

		rdfizer_annos = TAO::RDFizer.new(:annotations)
		rdfizer_spans = TAO::RDFizer.new(:spans)

		graph_uri_project = project.graph_uri
		graph_uri_docs = Doc.graph_uri

		sd.clear_db(db, graph_uri_project)

		annotations_col = []
		num_denotations_in_annotation_queue = 0

		docs_for_spans = []
		num_denotations_in_span_queue = 0

		num_denotations_in_current_doc = 0
		File.foreach(filepath).with_index do |docid, i|
			docid.chomp!.strip!
			doc = Doc.find(docid)

			# rdfize and store annotations
			if doc.denotations.where("denotations.project_id = ?", project.id).exists?
				hannotations = doc.hannotations(project)
				num_denotations_in_current_doc = hannotations[:denotations].length

				annotations_col << hannotations
				num_denotations_in_annotation_queue += num_denotations_in_current_doc

				# batch processing for rdfizing annotations
				if num_denotations_in_annotation_queue >= size_batch_annotations
					begin
						annos_ttl = rdfizer_annos.rdfize(annotations_col)
						sd.add(db, annos_ttl, graph_uri_project, "text/turtle")
					rescue => e
						@job.messages << Message.create({body: "failed in rdfizing annotations to #{annotations_col.length} docs: #{e.message}"})
					end
					annotations_col.clear
					num_denotations_in_annotation_queue = 0
				end
			end

			# rdfize and store spans
			doc_last_indexed_at = doc.last_indexed_at(sd)
			if doc_last_indexed_at.nil? || doc.denotations.where("denotations.project_id = ? AND denotations.updated_at > ?", project.id, doc_last_indexed_at).exists?
				docs_for_spans << doc
				num_denotations_in_span_queue += num_denotations_in_current_doc

				if num_denotations_in_span_queue >= size_batch_spans
					begin
						sd.with_transaction(db) do |txID|
							docs_for_spans.each do |d|
								graph_uri_doc = d.graph_uri
								sd.clear_db_in_transaction(db, txID, graph_uri_doc)
								spans = d.hdenotations_all
								spans_ttl = rdfizer_spans.rdfize([spans])
								sd.add_in_transaction(db, txID, spans_ttl, graph_uri_doc, "text/turtle")
								update_time_in_transaction(sd, db, txID, graph_uri_doc)
							end
						end
					rescue => e
						@job.messages << Message.create({body: "failed in rdfizing spans in #{docs_for_spans.length} docs: #{e.message}"})
					end
					docs_for_spans.clear
					num_denotations_in_current_doc = 0
			  end
			end

			@job.update_attribute(:num_dones, i + 1)
		end

		unless annotations_col.empty?
			begin
				annos_ttl = rdfizer_annos.rdfize(annotations_col)
				sd.add(db, annos_ttl, graph_uri_project, "text/turtle")
			rescue => e
				@job.messages << Message.create({body: "failed in rdfizing #{annotations_col.length} docs: #{e.message}"})
			end
		end

		unless docs_for_spans.empty?
			begin
				sd.with_transaction(db) do |txID|
					docs_for_spans.each do |doc|
						graph_uri_doc = doc.graph_uri
						sd.clear_db_in_transaction(db, txID, graph_uri_doc)
						spans = doc.hdenotations_all
						spans_ttl = rdfizer_spans.rdfize([spans])
						sd.add_in_transaction(db, txID, spans_ttl, graph_uri_doc, "text/turtle")
						update_time_in_transaction(sd, db, txID, graph_uri_doc)
					end
				end
			rescue => e
				@job.messages << Message.create({body: "failed in rdfizing spans in #{docs_for_spans.length} docs: #{e.message}"})
			end
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

	def update_time_in_transaction(sd, database, txID, graph_uri)
		update = <<-HEREDOC
			DELETE {<#{graph_uri}> <http://www.w3.org/ns/prov#generatedAtTime> ?generationTime .}
			WHERE {<#{graph_uri}> <http://www.w3.org/ns/prov#generatedAtTime> ?generationTime .}
		HEREDOC
		sd.update_in_transaction(database, txID, update)

		statement = %|<#{graph_uri}> <http://www.w3.org/ns/prov#generatedAtTime> "#{DateTime.now.iso8601}"^^xsd:dateTime .|
		sd.add_in_transaction(database, txID, statement, nil, "text/turtle")
	end

end
