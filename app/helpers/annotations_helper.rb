require 'text_alignment'

module AnnotationsHelper
	def annotations_count_helper(project, doc = nil, span = nil)
		project = doc.projects.first if project.nil? && doc.projects_num == 1
		if project
			if project.annotations_accessible?(current_user)
				if doc.present?
					doc.get_denotations_count(project.id, span)
				else
					project.denotations_num
				end
			else
				'<i class="fa fa-bars" aria-hidden="true" title="blinded"></i>'.html_safe
			end
		else
			if doc.present?
				doc.get_denotations_count(nil, span)
			else
				raise "count of all denotations?"
			end
		end
	end

	def annotations_url
		"#{url_for(only_path: false)}".sub('/visualize', '').sub('/list_view', '').sub('/merge_view', '').sub('/annotations', '') + '/annotations'
	end  

	def annotations_path
		"#{url_for(only_path: true)}".sub('/visualize', '').sub('/list_view', '').sub('/merge_view', '').sub('/annotations', '') + '/annotations'
	end  

	def annotations_json_path
		url_query = URI.parse( request.fullpath ).query
		url_query = "?#{url_query}" if url_query.present? 
		"#{ annotations_path }.json#{ url_query }" 
	end  

	def link_to_editor(project, editor, source_url)
		editor.parameters.each_key{|k| editor.parameters[k] = source_url + '.json' if editor.parameters[k] == '_annotations_url_'}
		editor.parameters[:config] = project.textae_config if editor.name =~ /^TextAE/ && project && project.textae_config.present?
		parameters_str = editor.parameters.map{|p| p.join('=')}.join('&')
		connector = editor.url.include?('?') ? '&' : '?'
		url = "#{editor.url}#{connector}#{parameters_str}"
		link_to editor.name, url, :class => 'tab', :title => editor.description
	end

	def annotations_obtain_path
		if params[:sourceid].present?
			if params[:begin].present?
				annotations_obtain_in_span_project_sourcedb_sourceid_docs_path(@project.name, @doc.sourcedb, @doc.sourceid, params[:begin], params[:end])
			else
				annotations_obtain_project_sourcedb_sourceid_docs_path(@project.name, @doc.sourcedb, @doc.sourceid)
			end
		else
			project_annotations_obtain_path(@project.name)
		end
	end

	def get_doc_info (annotations)
		sourcedb = annotations[:sourcedb]
		sourceid = annotations[:sourceid]
		docinfo  = "#{sourcedb}-#{sourceid}"
	end

end
