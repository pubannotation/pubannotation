module DivsHelper
	def div_link_helper(project, doc)
		if project.present?
			href = show_project_sourcedb_sourceid_divs_docs_path(params[:project_id], params[:sourcedb], params[:sourceid], doc.serial)
		else
			href = doc_sourcedb_sourceid_divs_show_path(params[:sourcedb], params[:sourceid], doc.serial)
		end
		link_to t('views.shared.show'), href
	end
end
