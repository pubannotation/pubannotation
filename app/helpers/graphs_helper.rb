module GraphsHelper

	def solution2maxspan_url (solution, projects = nil, extension_size = 0, context_size = 0)
		span_urls = solution.values.select{|v| span?(v["value"])}.map{|v| v["value"]}
		ranges = span_urls.map{|s| span_offset(s)}
		mbeg = ranges.map{|r| r[0]}.min - extension_size
		mend = ranges.map{|r| r[1]}.max + extension_size
		span_url = "#{span_prefix(span_urls[0])}#{mbeg}-#{mend}"
		annotation_url = span_url + '/annotations.json'
		options = "projects=#{projects.join(',')}&context_size=15"
		span_url += '?' + options
		annotation_url += '?' + options
		[span_url, annotation_url]
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
