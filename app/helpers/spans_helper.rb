module SpansHelper
  def span_link(doc, span)
    link_to "#{span[:begin]}-#{span[:end]}", doc.span_url(span)
  end
end
