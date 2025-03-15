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
			Denotation.find_by(project_id:project, doc_id:doc, hid:anno[:id])
		when 'block'
			Block.find_by(project_id:project, doc_id:doc, hid:anno[:id])
		when 'relation'
			Relation.find_by(project_id:project, doc_id:doc, hid:anno[:id])
		end

		raise "Could not find the annotation. Annotations might be changed." if ann.nil?
		ann.span
	end

	def sort_button_helper(sort_key)
		link_to_unless_current(
			content_tag(:i, '', class: "fa fa-sort-desc", "aria-hidden" => "true"),
			params.permit(:controller, :action, :type, :element).merge(sort_key: sort_key),
			title: "Sort by #{sort_key}. Frequent ones come first."
		)
	end

	def simple_paginate
		current_page = params[:page].nil? ? 1 : params[:page].to_i
		nav = ''
		nav += link_to(content_tag(:i, '', class: "fa fa-angle-double-left", "aria-hidden" => "true"), params.permit(:controller, :action, :element, :type, :sort_key, :sort_direction).except(:page), title: "First", class: 'page') if current_page > 2
		nav += link_to(content_tag(:i, '', class: "fa fa-angle-left", "aria-hidden" => "true"), params.permit(:controller, :action, :element, :type, :sort_key, :sort_direction).merge(page: current_page - 1), title: "Previous", class: 'page') if current_page > 1
		nav += content_tag(:span, "Page #{current_page}", class: 'page')
		nav += link_to(content_tag(:i, '', class: "fa fa-angle-right", "aria-hidden" => "true"), params.permit(:controller, :action, :element, :type, :sort_key, :sort_direction).merge(page: current_page + 1), title: "Next", class: 'page') unless params[:last_page]
		content_tag(:nav, nav.html_safe, class: 'pagination')
	end
end
