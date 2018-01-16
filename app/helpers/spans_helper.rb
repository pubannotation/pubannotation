module SpansHelper
	def span_link(doc, span)
		if span.respond_to?(:push)
			span.map{|s| link_to "#{s[:begin]}-#{s[:end]}", doc.span_url(s)}.join(', ').html_safe
		else
			link_to "#{span[:begin]}-#{span[:end]}", doc.span_url(span)
		end
	end
end
