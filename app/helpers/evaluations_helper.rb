module EvaluationsHelper

	def pair2span_urls (pair, doc, sproject, rproject, extension_size = 0, context_size = 0)
		sbeg, send = if pair[:study]
			span_helper(pair[:study], pair[:type], sproject, doc)
		else
			span_helper(pair[:reference], pair[:type], rproject, doc)
		end

		s = span_show_project_sourcedb_sourceid_docs_url(sproject.name, pair[:sourcedb], pair[:sourceid], sbeg, send)
		r = span_show_project_sourcedb_sourceid_docs_url(rproject.name, pair[:sourcedb], pair[:sourceid], sbeg, send)
		[s, r]
	end

	def span_helper(anno, type, project, doc)
		ann = case type
		when 'denotation'
			Denotation.where(project_id:project, doc_id:doc, hid:anno[:id]).first
		when 'relation'
			doc.subcatrels.where(project_id:project, hid:anno[:id]).first
		when 'modification'
			Modification.where(project_id:project, hid:anno[:id]).first
		end

		raise "Could not find the annotation. Annotations might be changed." if ann.nil?
		ann.span
	end

end
