module DivsHelper
  def div_link_helper(project, doc)
    if project.present?
      if params[:pmcdoc_id].present?
        href = project_pmcdoc_div_path(project.name, doc.sourceid, doc.serial)
      else
        href = show_project_sourcedb_sourceid_divs_docs_path(params[:project_id], params[:sourcedb], params[:sourceid], doc.serial)
      end
    else
      if params[:pmcdoc_id].present?
        href = pmcdoc_div_path(doc.sourceid, doc.serial)
      else
        href = doc_sourcedb_sourceid_divs_show_path(params[:sourcedb], params[:sourceid], doc.serial)
      end
    end
    link_to t('views.shared.show'),  href
  end
end
