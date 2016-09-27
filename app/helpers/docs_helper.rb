module DocsHelper

  def docs_count_cache_key
    cache_id = "count_#{@sourcedb.nil? ? 'docs' : @sourcedb}"
    cache_id += '_' + @project.name unless @project.nil?
    cache_id
  end

  def docs_count
    if @project
      if @sourcedb
        count = if @sourcedb == 'PubMed'
          @project.docs.where(sourcedb: @sourcedb).count
        else
          @project.docs.where(sourcedb: @sourcedb, serial: 0).count
        end
      else
        # count = @project.pmdocs_count + @project.pmcdocs_count
        count = @project.docs.where(serial: 0).count #if count < 1000
      end
    else
      if @sourcedb
        count = if @sourcedb == 'PubMed'
          Doc.where(sourcedb: @sourcedb).count
        else
          Doc.where(sourcedb: @sourcedb, serial: 0).count
        end
      else
        count = Doc.docs_count(current_user)
      end
    end
    number_with_delimiter(count, :delimiter => ',')
  end

  def sourcedb_count(user, project)
    counts = if project.nil?
      # Doc.count_per_sourcedb(user)
      Doc.count_per_sourcedb(nil)
    else
      project.docs.where("serial = ?", 0).group(:sourcedb).count
    end
  end

  def sourceid_index_link_helper(doc)
    if params[:project_id].present?
      link_to doc.sourcedb, index_project_sourcedb_docs_path(params[:project_id], doc.sourcedb)
    else
      link_to doc.sourcedb, doc_sourcedb_index_path(doc.sourcedb)
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
    docs = Doc.select(:sourcedb).sourcedbs.uniq

    if current_user
      docs.delete_if do |doc|
        doc.sourcedb.include?(Doc::UserSourcedbSeparator) && doc.sourcedb.split(Doc::UserSourcedbSeparator)[1] != current_user.username
      end
    else
      docs.delete_if{|doc| doc.sourcedb.include?(Doc::UserSourcedbSeparator)}
    end

    docs.collect{|doc| [doc.sourcedb, doc.sourcedb]}
  end
end
