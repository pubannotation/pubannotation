module SpansHelper
	def span_link(doc, span)
		if span.respond_to?(:push)
			span.map{|s| link_to "#{s[:begin]}-#{s[:end]}", span_url(doc, s)}.join(', ').html_safe
		else
			link_to "#{span[:begin]}-#{span[:end]}", span_url(doc, span)
		end
	end

	def span_url(doc, span)
		doc_sourcedb_sourceid_span_show_url(doc.sourcedb, doc.sourceid, span[:begin], span[:end])
	end
end
