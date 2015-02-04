module DenotationsHelper
  def denotations_count_helper(project, doc, span)
    if doc.present?
      doc.get_denotations_count(project, span)
    else
      project.denotations_count
    end
  end

  def span_link_url_helper(doc, span)
    if doc.has_divs?
      Rails.application.routes.url_helpers.doc_sourcedb_sourceid_divs_span_show_url(doc.sourcedb, doc.sourceid, doc.serial, span[:begin], span[:end])
    else
      Rails.application.routes.url_helpers.doc_sourcedb_sourceid_span_show_url(doc.sourcedb, doc.sourceid, span[:begin], span[:end])
    end
  end

  def span_link_helper(doc, span)
    link_to "#{span[:begin]}-#{span[:end]}", span_link_url_helper(doc, span) 
  end

  def get_span_index (doc, denotations)
    denotations.map{|d| {id:d[:id], span:d[:span], obj:span_link_url_helper(doc, d[:span])}}.uniq{|d| d[:span]} if denotations.present?
  end
end
