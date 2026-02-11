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
		params.permit(:controller, :action).merge(controller: :spans, action: action)
	end

	def docs_count_cache_key
		cache_id = "count_#{@sourcedb.nil? ? 'docs' : @sourcedb}"
		cache_id += '_' + @project.name unless @project.nil?
		cache_id
	end

	def docs_count
		count = if @project
			if @sourcedb
				@project.docs_stat[@sourcedb]
			else
				@project.docs_count
			end
		else
			if @sourcedb
				Project.docs_stat[@sourcedb]
			else
				Project.docs_count
			end
		end
		number_with_delimiter(count, :delimiter => ',')
	end

	def sourcedb_counts(project = nil)
		if project.nil?
			Project.docs_stat.present? ? Project.docs_stat : Project.docs_stat_update
			# Project.docs_stat_update
		else
			project.docs_stat.present? ? project.docs_stat : project.docs_stat_update
			# project.docs_stat_update
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
		params_to_text.except(:project, :projects) if except_actions.include?(params[:action])
		params_to_text = params.merge(controller: :docs, action: :show)

		html += link_to_unless_current 'JSON', params_to_text.permit(:controller, :action).merge(format: :json), :class => 'tab'
		html += link_to_unless_current 'TXT', params_to_text.permit(:controller, :action).merge(format: :txt), :class => 'tab'
	end

	def doc_snippet(doc)
		body = doc.body
		return '' if body.nil?

		keywords = @search_keywords
		if keywords.present?
			terms = keywords.split(/\s+/).reject { |t| t.blank? || t.length < 2 }

			# Find the earliest matching term position in the body
			match_pos = nil
			terms.each do |term|
				pos = body.downcase.index(term.downcase)
				if pos && (match_pos.nil? || pos < match_pos)
					match_pos = pos
				end
			end

			if match_pos
				# Start ~20 chars before the match so the keyword appears
				# near the left edge of the visible area (CSS text-overflow
				# truncates from the right).
				b = [match_pos - 20, 0].max

				# Adjust to a word boundary
				if b > 0
					space_pos = body.rindex(' ', b + 10)
					b = space_pos + 1 if space_pos && space_pos >= [b - 10, 0].max
				end

				result = body[b, 500]

				# Wrap matching terms in <em> for bold display
				terms.each do |term|
					result = result.gsub(/(#{Regexp.escape(term)})/i, '<em>\1</em>')
				end

				result = "...#{result}" if b > 0
				result
			else
				body[0, 200]
			end
		else
			body[0, 200]
		end
	end

end
