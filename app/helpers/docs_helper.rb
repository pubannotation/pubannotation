module DocsHelper

	def doc_show_path_helper
		if params.has_key? :project_id
			show_project_sourcedb_sourceid_docs_path(params[:project_id], params[:sourcedb], params[:sourceid])
		else
			doc_sourcedb_sourceid_show_path(params[:sourcedb], params[:sourceid])
		end
	end

	def span_show_path_helper
		action = params[:project_id].present? ? :project_doc_span_show : :doc_span_show
		params[:project_id].present? ? :project_doc_span_show : :doc_span_show
		params.merge(controller: :spans, action: action)
	end

	def docs_count_cache_key
		cache_id = "count_#{@sourcedb.nil? ? 'docs' : @sourcedb}"
		cache_id += '_' + @project.name unless @project.nil?
		cache_id
	end

	def docs_count
		count = if @project
			if @sourcedb
				@project.docs.where(sourcedb: @sourcedb).count
			else
				@project.docs.count #if count < 1000
			end
		else
			if @sourcedb
				Doc.where(sourcedb: @sourcedb).count
			else
				Doc.docs_count(current_user)
			end
		end
		number_with_delimiter(count, :delimiter => ',')
	end

	def sourcedb_count(user, project)
		counts = if project.nil?
			# Doc.count_per_sourcedb(user)
			Doc.count_per_sourcedb(nil)
		else
			project.docs.select(:sourcedb).group(:sourcedb).count
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
		except_actions = %w(doc_annotations_list_view doc_annotations_merge_view)

		params_to_text = params.dup
		params_to_text.except!(:project, :projects) if except_actions.include?(params[:action])
		params_to_text = params.merge(controller: :docs, action: :show)

		html += link_to_unless_current 'JSON', params_to_text.merge(format: :json), :class => 'tab'
		html += link_to_unless_current 'TXT', params_to_text.merge(format: :txt), :class => 'tab'
	end

	def doc_snippet(doc)
		snippet = doc.body
		em_open_pos = snippet.index('<em>')
		if em_open_pos
			em_close_pos = snippet.rindex('</em>')
			m = em_open_pos + (em_close_pos - em_open_pos) / 2
			b = m - 40
			e = m + 60
			if b < 0
				e -= b
				b = 0
			end
			if e > snippet.length
				e = snippet.length
			end
			snippet[b...e]
		else
			snippet[0 ... 100]
		end
	end
end
