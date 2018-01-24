require 'stardog'

class StoreRdfizedAnnotationsJob < Struct.new(:project, :filepath)
	include StateManagement
	include Stardog

	def perform
		size_batch_annotations = 5000
		size_batch_spans = 2500
		count = %x{wc -l #{filepath}}.split.first.to_i

		@job.update_attribute(:num_items, count)
		@job.update_attribute(:num_dones, 0)

		sd = stardog(Rails.application.config.ep_url, user: Rails.application.config.ep_user, password: Rails.application.config.ep_password)
		db = Rails.application.config.ep_database

		rdfizer_annos = TAO::RDFizer.new(:annotations)
		rdfizer_spans = TAO::RDFizer.new(:spans)

		graph_uri_project = project.graph_uri
		graph_uri_doc_spans = Doc.graph_uri + '/spans'

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
			if doc.denotations.where("denotations.project_id" => project.id).exists?
				hannotations = doc.hannotations(project)
				num_denotations_in_current_doc = hannotations[:denotations].length

				annotations_col << hannotations
				num_denotations_in_annotation_queue += num_denotations_in_current_doc

				# batch processing for rdfizing annotations
				if num_denotations_in_annotation_queue >= size_batch_annotations
					begin
						annos_ttl = rdfizer_annos.rdfize(annotations_col)
						r = sd.add(db, annos_ttl, graph_uri_project, "text/turtle")
						raise RuntimeError, "failure while adding RDFized data to the endpoint." unless r == 0
					rescue => e
						@job.messages << Message.create({body: "failed in storing rdfized annotations from #{annotations_col.length} docs: #{e.message}"})
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
								graph_uri_doc_spans = graph_uri_doc + '/spans'
								sd.clear_db_in_transaction(db, txID, graph_uri_doc_spans)
								spans = d.hdenotations_all
								spans_ttl = rdfizer_spans.rdfize([spans])
								r = sd.add_in_transaction(db, txID, spans_ttl, graph_uri_doc_spans, "text/turtle")
								raise RuntimeError, "failure while adding RDFized data to the endpoint." unless r == 0
								update_doc_metadata_in_transaction(sd, db, txID, graph_uri_doc, graph_uri_doc_spans)
							end
						end
					rescue => e
						@job.messages << Message.create({body: "failed in storing rdfized spans from #{docs_for_spans.length} docs: #{e.message}"})
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
				r = sd.add(db, annos_ttl, graph_uri_project, "text/turtle")
				raise RuntimeError, "failure while adding RDFized data to the endpoint." unless r == 0
			rescue => e
				@job.messages << Message.create({body: "failed in storing rdfized annotations from #{annotations_col.length} docs: #{e.message}"})
			end
		end

		unless docs_for_spans.empty?
			begin
				sd.with_transaction(db) do |txID|
					docs_for_spans.each do |doc|
						graph_uri_doc = doc.graph_uri
						graph_uri_doc_spans = graph_uri_doc + '/spans'
						sd.clear_db_in_transaction(db, txID, graph_uri_doc_spans)
						spans = doc.hdenotations_all
						spans_ttl = rdfizer_spans.rdfize([spans])
						r = sd.add_in_transaction(db, txID, spans_ttl, graph_uri_doc_spans, "text/turtle")
						raise RuntimeError, "failure while adding RDFized data to the endpoint." unless r == 0
						update_doc_metadata_in_transaction(sd, db, txID, graph_uri_doc, graph_uri_doc_spans)
					end
				end
			rescue => e
				@job.messages << Message.create({body: "failed in storing rdfized spans from #{docs_for_spans.length} docs: #{e.message}"})
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
			<#{graph_uri_project}> rdf:type tao:AnnotationDataSet ;
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
			<#{graph_uri_doc_spans}> rdf:type tao:AnnotationDataSet ;
				rdf:type oa:Annotation ;
				oa:has_body <#{graph_uri_doc_spans}> ;
				oa:has_target <#{graph_uri_doc}> ;
				prov:generatedAtTime "#{DateTime.now.iso8601}"^^xsd:dateTime .
		HEREDOC
		sd.add_in_transaction(database, txID, metadata, nil, "text/turtle")
	end

end
