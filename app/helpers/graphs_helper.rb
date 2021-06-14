module GraphsHelper
	def link_to_predefined_templates
		path = if params[:project_name].present?
			project_queries_path(@organization.name)
		elsif params[:collection_name].present?
			collection_queries_path(@organization.name)
		else
			queries_path
		end

		link_to 'Predefined templates:', path
	end

	def solution2span_url (solution, extension_size = 0)
		span_urls = solution.values.select{|v| span?(v["value"])}.map{|v| v["value"]}
		ranges = span_urls.map{|s| span_offset(s)}
		mbeg = ranges.map{|r| r[0]}.min - extension_size
		mend = ranges.map{|r| r[1]}.max + extension_size
		span_url = "#{span_prefix(span_urls[0])}#{mbeg}-#{mend}"
	end

	def parse_span_url (span_url)
		m = %r|sourcedb/(?<sourcedb>.+)/sourceid/(?<sourceid>.+)/spans/(?<begin>[0-9]+)-(?<end>[0-9]+)|.match(span_url)
		[m[:sourcedb], m[:sourceid], {begin:m[:begin].to_i, end:m[:end].to_i}]
	end

	def span_url2annotations (span_url, pnames, context_size = 0)
		sourcedb, sourceid, span = parse_span_url(span_url)
		doc = Doc.where(sourcedb:sourcedb, sourceid:sourceid).first
		projects = pnames.respond_to?(:each) ? pnames.map{|n| Project.find_by_name(n)} : Project.find_by_name(pnames)
		annotations = doc.hannotations(projects, span, context_size)
	end

	def span?(v)
		!!(%r|/spans/\d+-\d+$|.match(v))
	end

	def span_prefix(span_url)
		span_url[0..span_url.rindex('/')]
	end

	def span_offset(span_url)
		span_url[span_url.rindex('/') + 1 .. -1].split('-').map{|p| p.to_i}
	end
end
