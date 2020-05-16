module DocsHelper

  def doc_show_path_helper
    action = params[:project_id].present? ? :show_in_project : :show
    params.merge(controller: :docs, action: action).except(:divid, :begin, :end)
  end

  def div_show_path_helper
    action = params[:project_id].present? ? :show_in_project : :show
    params.merge(controller: :divs, action: action).except(:begin, :end)
  end

  def span_show_path_helper
    action = if params[:divid].present?
      params[:project_id].present? ? :project_div_span_show : :div_span_show
    else
      params[:project_id].present? ? :project_doc_span_show : :doc_span_show
    end
    params.merge(controller: :spans, action: action)
  end

  def docs_count_cache_key
    cache_id = "count_#{@sourcedb.nil? ? 'docs' : @sourcedb}"
    cache_id += '_' + @project.name unless @project.nil?
    cache_id
  end

  def docs_count
    if @project
      if @sourcedb
        count = if Doc.is_mdoc_sourcedb(@sourcedb)
          @project.docs.where(sourcedb: @sourcedb, serial: 0).count
        else
          @project.docs.where(sourcedb: @sourcedb).count
        end
      else
        # count = @project.pmdocs_count + @project.pmcdocs_count
        count = @project.docs.where(serial: 0).count #if count < 1000
      end
    else
      if @sourcedb
        count = if Doc.is_mdoc_sourcedb(@sourcedb)
          Doc.where(sourcedb: @sourcedb, serial: 0).count
        else
          Doc.where(sourcedb: @sourcedb).count
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
      project.docs.where(serial: 0).select(:sourcedb).group(:sourcedb).count
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

  def json_text_link_helper
    html = ''
    # Set actions which except projects and project params for link
    except_actions = %w(doc_annotations_list_view div_annotations_list_view doc_annotations_merge_view div_annotations_merge_view)

    params_to_text = params.dup
    params_to_text.except!(:project, :projects) if except_actions.include?(params[:action])
    controller = params[:divid].present? ? :divs : :docs
    params_to_text = params.merge(controller: controller, action: :show)

    html += link_to_unless_current 'JSON', params_to_text.merge(format: :json), :class => 'tab'
    html += link_to_unless_current 'TXT', params_to_text.merge(format: :txt), :class => 'tab'
  end
end
