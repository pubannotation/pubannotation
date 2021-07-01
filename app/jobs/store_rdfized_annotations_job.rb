class StoreRdfizedAnnotationsJob < ApplicationJob
	queue_as :low_priority

	def perform(project, filepath, options)
		size_batch_annotations = 5000
		size_batch_spans = 5000
		count = %x{wc -l #{filepath}}.split.first.to_i

		if @job
			@job.update_attribute(:num_items, count)
			@job.update_attribute(:num_dones, 0)
		end
		sd = stardog(Rails.application.config.ep_url, user: Rails.application.config.ep_user, password: Rails.application.config.ep_password)
		db = Rails.application.config.ep_database

		rdfizer_annos = TAO::RDFizer.new(:annotations)
		rdfizer_spans = TAO::RDFizer.new(:spans)

		graph_uri_project = project.graph_uri
		graph_uri_doc_spans = Doc.graph_uri + '/spans'

		sd.clear_db(db, graph_uri_project)

		skip_span_indexing = options[:skip_span_indexing]
		annotations_col = []
		num_denotations_in_annotation_queue = 0

		spans_indexed_queue = {}
		num_spans_in_span_queue = 0

		File.foreach(filepath).with_index do |line, i|
			docid = line.chomp.strip
			doc = Doc.find(docid)

			if doc.denotations.where("denotations.project_id" => project.id).exists?
				hannotations = doc.hannotations(project)
				num_denotations_in_current_doc = hannotations[:denotations].length

				# rdfize and store annotations
				# batch processing for rdfizing annotations
				if (num_denotations_in_annotation_queue > 0) && ((num_denotations_in_annotation_queue + num_denotations_in_current_doc) >= size_batch_annotations)
					begin
						annos_ttl = rdfizer_annos.rdfize(annotations_col)
						r = sd.add(db, annos_ttl, graph_uri_project, "text/turtle")
						raise RuntimeError, "failure while adding RDFized data to the endpoint." unless r == 0
					rescue => e
						if @job
							@job.messages << Message.create({body: "failed in storing #{num_denotations_in_annotation_queue} rdfized annotations from #{annotations_col.length} docs: #{e.message}"})
						else
							raise ArgumentError, e.message
						end
					end
					annotations_col.clear
					num_denotations_in_annotation_queue = 0
				else
					annotations_col << hannotations
					num_denotations_in_annotation_queue += num_denotations_in_current_doc
				end

				# rdfize and store spans
				unless skip_span_indexing
					doc_last_indexed_at = doc.last_indexed_at(sd)
					if doc_last_indexed_at.nil? || doc.denotations.where("denotations.project_id = ? AND denotations.updated_at > ?", project.id, doc_last_indexed_at).exists?
						spans = doc.get_denotations_hash_all
						num_spans_in_current_doc = spans.length

						if (num_spans_in_span_queue > 0) && ((num_spans_in_span_queue + num_spans_in_current_doc) >= size_batch_spans)
							begin
								sd.with_transaction(db) do |txID|
									spans_indexed_queue.each do |graph_uri_doc, spans|
										graph_uri_doc_spans = graph_uri_doc + '/spans'
										sd.clear_db_in_transaction(db, txID, graph_uri_doc_spans)
										spans_ttl = rdfizer_spans.rdfize([spans])
										r = sd.add_in_transaction(db, txID, spans_ttl, graph_uri_doc_spans, "text/turtle")
										raise RuntimeError, "failure while adding RDFized spans to <#{graph_uri_doc_spans}>." unless r && r.status == 200
										update_doc_metadata_in_transaction(sd, db, txID, graph_uri_doc, graph_uri_doc_spans)
									end
								end
							rescue => e
								if @job
									@job.messages << Message.create({body: "failed in storing #{num_spans_in_span_queue} rdfized spans from #{spans_indexed_queue.length} docs: #{e.message}"})
								else
									raise ArgumentError, e.message
								end
							ensure
								spans_indexed_queue.clear
								num_spans_in_span_queue = 0
							end
						else
							spans_indexed_queue[doc.graph_uri] = spans
							num_spans_in_span_queue += num_spans_in_current_doc
					  end
					end
				end
			end

			if @job
				@job.update_attribute(:num_dones, i + 1)
			end
		end

		unless annotations_col.empty?
			begin
				annos_ttl = rdfizer_annos.rdfize(annotations_col)
				r = sd.add(db, annos_ttl, graph_uri_project, "text/turtle")
				raise RuntimeError, "failure while adding RDFized data to the endpoint." unless r == 0
			rescue => e
				if @job
					@job.messages << Message.create({body: "failed in storing #{num_denotations_in_annotation_queue} rdfized annotations from the last #{annotations_col.length} docs: #{e.message}"})
				else
					raise ArgumentError, e.message
				end
			end
		end

		unless spans_indexed_queue.empty?
			begin
				sd.with_transaction(db) do |txID|
					spans_indexed_queue.each do |graph_uri_doc, spans|
						graph_uri_doc_spans = graph_uri_doc + '/spans'
						sd.clear_db_in_transaction(db, txID, graph_uri_doc_spans)
						spans_ttl = rdfizer_spans.rdfize([spans])
						r = sd.add_in_transaction(db, txID, spans_ttl, graph_uri_doc_spans, "text/turtle")
						raise RuntimeError, "failure while adding RDFized spans to <#{graph_uri_doc_spans}>." unless r && r.status == 200
						update_doc_metadata_in_transaction(sd, db, txID, graph_uri_doc, graph_uri_doc_spans)
					end
				end
			rescue => e
				if @job
					@job.messages << Message.create({body: "failed in storing #{num_spans_in_span_queue} rdfized spans from the last #{spans_indexed_queue.length} docs: #{e.message}"})
				else
					raise ArgumentError, e.message
				end
			end
		end

		update_project_metadata(sd, db, project)

		File.unlink(filepath)
	end

	private

	def update_project_metadata(sd, database, project)
		graph_uri_project = project.graph_uri
		graph_uri_project_docs = project.docs_uri

		update = <<-HEREDOC
			DELETE {<#{graph_uri_project}> prov:generatedAtTime ?generationTime .}
			WHERE  {<#{graph_uri_project}> prov:generatedAtTime ?generationTime .}
		HEREDOC
		sd.update(database, update)

		metadata = <<-HEREDOC
			<#{graph_uri_project}> rdf:type pubann:Project ;
				rdf:type oa:Annotation ;
				oa:has_body <#{graph_uri_project}> ;
				oa:has_target <#{graph_uri_project_docs}> ;
				prov:generatedAtTime "#{DateTime.now.iso8601}"^^xsd:dateTime .
		HEREDOC
		sd.add(database, metadata, nil, "text/turtle")
	end

	def update_doc_metadata_in_transaction(sd, database, txID, graph_uri_doc, graph_uri_doc_spans)
		update = <<-HEREDOC
			DELETE {<#{graph_uri_doc_spans}> prov:generatedAtTime ?generationTime .}
			WHERE  {<#{graph_uri_doc_spans}> prov:generatedAtTime ?generationTime .}
		HEREDOC
		sd.update_in_transaction(database, txID, update)

		metadata = <<-HEREDOC
			<#{graph_uri_doc_spans}> rdf:type oa:Annotation ;
				oa:has_body <#{graph_uri_doc_spans}> ;
				oa:has_target <#{graph_uri_doc}> ;
				prov:generatedAtTime "#{DateTime.now.iso8601}"^^xsd:dateTime .
		HEREDOC
		sd.add_in_transaction(database, txID, metadata, nil, "text/turtle")
	end

end
