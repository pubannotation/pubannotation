module DocsHelper
  def sourceid_index_link_helper(doc)
    if params[:project_id].present?
      link_to doc.sourcedb, sourceid_index_project_sourcedb_docs_path(params[:project_id], doc.sourcedb)  
    else
      link_to doc.sourcedb, doc_sourcedb_sourceid_index_path(doc.sourcedb)
    end
  end
  
  def source_db_index_docs_count_helper(docs, doc)
    count = docs.same_sourcedb_sourceid(doc.sourcedb, doc.sourceid).count
    if count.class == Fixnum
      return "(#{count})"
    else
      count.each do |key, val|
        return "(#{val})"
      end
    end
  end

  def sourcedb_options_for_select
    docs = Doc.select(:sourcedb).source_dbs.uniq
    docs.collect{|doc| [doc.sourcedb, doc.sourcedb]}
  end
end
