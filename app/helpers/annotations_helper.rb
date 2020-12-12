require 'text_alignment'

module AnnotationsHelper
	def annotations_count_helper(project, doc = nil, span = nil)
		project = doc.projects.first if project.nil? && doc.projects_num == 1
		if !project.present? || project.annotations_accessible?(current_user)
			if doc.present?
				doc.get_denotations_num(project, span)
			else
				project.denotations_num
			end
		else
			'<i class="fa fa-bars" aria-hidden="true" title="blinded"></i>'.html_safe
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

	def editor_annotation_url(editor, source_url)
		editor.parameters.each_key{|k| editor.parameters[k] = source_url + '.json' if editor.parameters[k] == '_annotations_url_'}
		parameters_str = editor.parameters.map{|p| p.join('=')}.join('&')
		connector = editor.url.include?('?') ? '&' : '?'
		url = "#{editor.url}#{connector}#{parameters_str}"
	end

	def link_to_editor(project, editor, source_url)
		editor.parameters.each_key{|k| editor.parameters[k] = source_url + '.json' if editor.parameters[k] == '_annotations_url_'}
		editor.parameters[:config] = project.textae_config if editor.name =~ /^TextAE/ && project && project.textae_config.present?
		parameters_str = editor.parameters.map{|p| p.join('=')}.join('&')
		connector = editor.url.include?('?') ? '&' : '?'
		url = "#{editor.url}#{connector}#{parameters_str}"
		link_to editor.name, url, :class => 'tab', :title => editor.description
	end

	def get_focus(options)
		if options.present? && options[:params].present? && options[:params][:begin].present? && options[:params][:context_size]
			sbeg = options[:params][:begin].to_i
			send = options[:params][:end].to_i
			context_size = options[:params][:context_size].to_i
			fbeg = (context_size < sbeg) ? context_size : sbeg
			fend = send - sbeg + fbeg
			{begin: fbeg, end: fend}
		end
	end

	def set_denotations_begin_end(denotations, options)
		denotations.each do |d|
			d[:span][:begin] -= options[:params][:begin].to_i
			d[:span][:end]   -= options[:params][:begin].to_i
			if options[:params][:context_size].present?
				d[:span][:begin] += options[:params][:context_size].to_i
				d[:span][:end] += options[:params][:context_size].to_i
			end
		end
		return denotations
	end

	def project_annotations_rdf_link_helper(project)
		if project.annotations_zip_downloadable == true && project.rdfwriter.present?
			file_path = project.annotations_rdf_system_path
			
			if File.exist?(file_path) == true
				rdf_created_at = File.ctime(file_path)
				# when ZIP file exists 
				html = link_to "Download '#{project.annotations_rdf_filename}'", project_annotations_rdf_path(project.name), :class => 'button'
				html += content_tag :span, "#{rdf_created_at.strftime("#{t('controllers.shared.created_at')}:%Y-%m-%d %T")}", :class => 'rdf_time_stamp'
				if rdf_created_at < project.annotations_updated_at
					html += link_to t('controllers.annotations.update_rdf'), project_create_annotations_rdf_path(project.name, :update => true), :class => 'button', :style => "margin-left: 0.5em", :confirm => t('controllers.annotations.confirm_create_rdf')
				end
				if project.user == current_user
					html += link_to t('views.shared.delete'), project_delete_annotations_rdf_path(project.name), confirm: t('controllers.shared.confirm_delete'), :class => 'button'
				end
				html
			else
				# when ZIP file deos not exists 
				delayed_job_tasks = ActiveRecord::Base.connection.execute('SELECT * FROM delayed_jobs').select{|delayed_job| delayed_job['handler'].include?(project.name) && delayed_job['handler'].include?('create_annotations_rdf')}
				if project.user == current_user
					if delayed_job_tasks.blank?
						# when delayed_job exists
						link_to t('controllers.annotations.create_rdf'), project_create_annotations_rdf_path(project.name), :class => 'button', :confirm => t('controllers.annotations.confirm_create_rdf')
					else
						# delayed_job does not exists
						t('views.shared.rdf.delayed_job_present')
					end
				else
					t('views.shared.rdf.download_not_available')
				end
			end    
		end    
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

	def annotations_form_action_helper
		if params[:id].present?
			annotations_project_doc_path(@project.name, @doc.id)
		else
			annotations_generate_project_sourcedb_sourceid_docs_path(@project.name, @doc.sourcedb, @doc.sourceid)
		end
	end

	def get_doc_info (annotations)
		sourcedb = annotations[:sourcedb]
		sourceid = annotations[:sourceid]
		docinfo  = "#{sourcedb}-#{sourceid}"
	end

end
