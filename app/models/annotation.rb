class Annotation < ActiveRecord::Base
	include ApplicationHelper
	include AnnotationsHelper

	# To produce an array of annotations for export.
	# The initial row of the array to contain the headers
	def self.hash_to_array(annotations, textae_config = nil)
		array = []

		headers = ["Id", "Subject", "Object", "Predicate", "Lexical cue"]

		text = annotations[:text]
		lexical_cues = {}

		attrs_idx = nil
		attr_preds = []

		if annotations[:attributes].present?
			attrs = annotations[:attributes]
			attrs_idx = attrs.inject({}) do |idx, a|
				idx.merge("#{a[:subj]}&#{a[:pred]}" => a)
			end
			attr_preds = if textae_config.present? && textae_config[:"attribute types"].present?
				textae_config[:"attribute types"].collect{|t| t[:pred]}
			else
				attrs.collect{|a| a[:pred]}.uniq.sort
			end
		end

		array << headers + attr_preds

		if annotations[:denotations].present?
			annotations[:denotations].each do |a|
				spans = a[:span].class == Array ? a[:span] : [a[:span]]
				lexical_cues[a[:id]] = spans.collect{|s| text[s[:begin]...s[:end]]}.join(' ').chomp
				spant = spans.collect{|s| "#{s[:begin]}-#{s[:end]}"}.to_csv.chomp
				attrs = attr_preds.collect do |pred|
					att = attrs_idx["#{a[:id]}&#{pred}"]
					att.nil? ? nil : att[:obj]
				end
				array << [a[:id], spant, a[:obj], 'denotes', lexical_cues[a[:id]]] + attrs
			end
		end

		if annotations[:relations].present?
			annotations[:relations].each do |a|
				lexical_cues[a[:id]] = [lexical_cues[a[:subj]], lexical_cues[a[:obj]]].to_csv.chomp
				array << [a[:id], a[:subj], a[:obj], a[:pred], lexical_cues[a[:id]]]
			end
		end

		if annotations[:modifications].present?
			annotations[:modifications].each do |a|
				array << [a[:id], a[:obj], a[:pred], 'hasMood', lexical_cues[a[:obj]]]
			end
		end

		array
	end

	def self.hash_to_tsv(annotations, textae_config = nil)
		array = self.hash_to_array(annotations, textae_config)
		array[0][0] = '# ' + array[0][0]
		tsv = CSV.generate(col_sep:"\t") do |csv|
			array.each{|a| csv << a}
		end
		return tsv
	end

	def self.hash_to_dic_array(annotations)
		array = []

		headers = ["Term", "Identifier"]
		array << headers

		text = annotations[:text]
		if annotations[:denotations].present?
			annotations[:denotations].each do |a|
				spans = a[:span].class == Array ? a[:span] : [a[:span]]
				lexical_cue = spans.collect{|s| text[s[:begin]...s[:end]]}.join(' ').chomp
				array << [lexical_cue, a[:obj]]
			end
		end

		array.uniq
	end

	def self.dic_array_to_tsv(dic)
		dic[0][0] = '# ' + dic[0][0]
		CSV.generate(col_sep:"\t") do |csv|
			dic.each{|a| csv << a}
		end
	end

	def self.hash_to_dic(annotations)
		array = self.hash_to_dic_array(annotations)
		self.dic_array_to_tsv(array)
	end

	# normalize annotations passed by an HTTP call
	def self.normalize!(annotations, prefix = nil)
		raise ArgumentError, "annotations must be a hash." unless annotations.class == Hash
		raise ArgumentError, "annotations must include a 'text'"  unless annotations[:text].present?

		if annotations[:sourcedb].present?
			annotations[:sourcedb] = 'PubMed' if annotations[:sourcedb].downcase == 'pubmed'
			annotations[:sourcedb] = 'PMC' if annotations[:sourcedb].downcase == 'pmc'
			annotations[:sourcedb] = 'FirstAuthors' if annotations[:sourcedb].downcase == 'firstauthors'
		end

		if annotations[:denotations].present?
			raise ArgumentError, "'denotations' must be an array." unless annotations[:denotations].class == Array
			symbolized_denotations = annotations[:denotations].map { |d| d.class == Hash ? d.deep_symbolize_keys : d }

			annotations = Annotation.chain_spans(annotations)

			ids = symbolized_denotations.collect{|d| d[:id]}.compact
			idnum = 1

			symbolized_denotations.each do |a|
				raise ArgumentError, "a denotation must have a 'span' or a pair of 'begin' and 'end'." unless (a[:span].present? && a[:span][:begin].present? && a[:span][:end].present?) || (a[:begin].present? && a[:end].present?)
				raise ArgumentError, "a denotation must have an 'obj'." unless a[:obj].present?

				unless a.has_key? :id
					idnum += 1 until !ids.include?('T' + idnum.to_s)
					a[:id] = 'T' + idnum.to_s
					idnum += 1
				end

				a[:span] = {begin: a[:begin], end: a[:end]} if !a[:span].present? && a[:begin].present? && a[:end].present?

				a[:span][:begin] = a[:span][:begin].to_i if a[:span][:begin].is_a? String
				a[:span][:end]   = a[:span][:end].to_i   if a[:span][:end].is_a? String

				raise ArgumentError, "the begin offset must be bigger than or equal to 0: #{a}" unless a[:span][:begin] >= 0
				raise ArgumentError, "the begin offset must be smaller than the length of the text: #{a}" unless a[:span][:begin] < annotations[:text].length

				raise ArgumentError, "the end offset must be bigger than 0: #{a}" unless a[:span][:end] > 0
				raise ArgumentError, "the end offset must be smaller than or equal to the length of the text: #{a}" unless a[:span][:end] <= annotations[:text].length

				raise ArgumentError, "the end offset must be bigger than the begin offset: #{a}" unless a[:span][:begin] < a[:span][:end]
			end
		end

		d_ids = nil

		if annotations[:relations].present?
			raise ArgumentError, "'relations' must be an array." unless annotations[:relations].class == Array

			d_ids = annotations[:denotations].collect{|a| a[:id]}

			symbolized_relations = annotations[:relations].map {|a| a.class == Hash ? a.symbolize_keys : a}

			ids = symbolized_relations.collect{|a| a[:id]}.compact
			idnum = 1

			symbolized_relations.each do |a|
				raise ArgumentError, "a relation must have 'subj', 'obj' and 'pred'." unless a[:subj].present? && a[:obj].present? && a[:pred].present?
				raise ArgumentError, "'subj' and 'obj' of a relation must reference to a denotation: [#{a}]." unless (d_ids.include? a[:subj]) && (d_ids.include? a[:obj])

				unless a.has_key? :id
					idnum += 1 until !ids.include?('R' + idnum.to_s)
					a[:id] = 'R' + idnum.to_s
					idnum += 1
				end
			end
		end

		if annotations[:attributes].present?
			raise ArgumentError, "'attributes' must be an array." unless annotations[:attributes].class == Array
			symbolized_attributes = annotations[:attributes].map {|a| a.class == Hash ? a.symbolize_keys : a}

			d_ids ||= annotations[:denotations].collect{|a| a[:id]}

			ids = symbolized_attributes.collect{|a| a[:id]}.compact
			idnum = 1

			symbolized_attributes.each do |a|

				# TODO: to remove the following line after TextAE is updated.
				a[:obj] = true unless a[:obj].present?

				raise ArgumentError, "An attribute must have 'subj', 'obj' and 'pred'." unless a[:subj].present? && a[:obj].present? && a[:pred].present?
				raise ArgumentError, "The 'subj' of an attribute must reference to a denotation: [#{a}]." unless d_ids.include? a[:subj]

				unless a.has_key? :id
					idnum += 1 until !ids.include?('A' + idnum.to_s)
					a[:id] = 'A' + idnum.to_s
					idnum += 1
				end
			end
		end

		if annotations[:modifications].present?
			raise ArgumentError, "'modifications' must be an array." unless annotations[:modifications].class == Array
			symbolized_modifications = annotations[:modifications].map {|a| a.class == Hash ? a.symbolize_keys : a}

			d_ids ||= annotations[:denotations].collect{|a| a[:id]}
			dr_ids = d_ids + annotations[:relations].collect{|a| a[:id]}

			ids = symbolized_modifications.collect{|a| a[:id]}.compact
			idnum = 1

			symbolized_modifications.each do |a|
				raise ArgumentError, "A modification must have 'pred' and 'obj'." unless a[:pred].present? && a[:obj].present?
				raise ArgumentError, "The 'obj' of a modification must reference to a denotation or a relation: [#{a}]." unless dr_ids.include? a[:obj]

				unless a.has_key? :id
					idnum += 1 until !ids.include?('M' + idnum.to_s)
					a[:id] = 'M' + idnum.to_s
					idnum += 1
				end
			end
		end

		if prefix.present?
			annotations[:denotations].each {|a| a[:id] = prefix + '_' + a[:id]} if annotations[:denotations].present?
			annotations[:relations].each {|a| a[:id] = prefix + '_' + a[:id]; a[:subj] = prefix + '_' + a[:subj]; a[:obj] = prefix + '_' + a[:obj]} if annotations[:relations].present?
			annotations[:attributes].each {|a| a[:id] = prefix + '_' + a[:id]; a[:subj] = prefix + '_' + a[:subj]} if annotations[:attributes].present?
			annotations[:modifications].each {|a| a[:id] = prefix + '_' + a[:id]; a[:obj] = prefix + '_' + a[:obj]} if annotations[:modifications].present?
		end

		annotations
	end

	def self.chain_spans(annotations)
		r = annotations[:denotations].inject({denotations:[], chains:[]}) do |m, d|
			if (d[:span].class == Array) && (d[:span].length > 1)
				last = d[:span].length - 1
				d[:span].each_with_index do |s, i|
					obj = (i == last) ? d[:obj] : '_FRAGMENT'
					m[:denotations] << {id:d[:id] + "-#{i}", span:s, obj:obj}
					m[:chains] << {id:'C-' + d[:id] + "-#{i-1}", pred:'_lexicallyChainedTo', subj: d[:id] + "-#{i}", obj: d[:id] + "-#{i-1}"} if i > 0
				end
			else
				m[:denotations] << d
			end
			m
		end

		denotations = r[:denotations]
		chains = r[:chains]

		annotations[:denotations] = denotations
		unless chains.empty?
			annotations[:relations] ||=[]
			annotations[:relations] += chains
		end
		annotations
	end

	def self.bag_spans(annotations)
		denotations = annotations[:denotations]
		relations = annotations[:relations]

		tomerge = Hash.new

		new_relations = Array.new
		relations.each do |ra|
			if ra[:pred] == '_lexicallyChainedTo'
				tomerge[ra[:obj]] = ra[:subj]
			else
				new_relations << ra
			end
		end
		idx = Hash.new
		denotations.each_with_index {|ca, i| idx[ca[:id]] = i}

		mergedto = Hash.new
		tomerge.each do |from, to|
			to = mergedto[to] if mergedto.has_key?(to)
			fda = denotations[idx[from]]
			tda = denotations[idx[to]]
			tda[:span] = [tca[:span]] unless tca[:span].respond_to?('push')
			tca[:span].push (fca[:span])
			denotations.delete_at(idx[from])
			mergedto[from] = to
		end

		annotations[:denotations] = denotations
		annotations[:relations] = new_relations
		annotations
	end

	def self.bag_denotations(denotations, relations)
		mergedto = {}
		relations.each do |ra|
			if ra[:pred] == '_lexicallyChainedTo'
				# To see if either subjet or object is already merged to another.
				ra[:subj] = mergedto[ra[:subj]] if mergedto.has_key? ra[:subj]
				ra[:obj] = mergedto[ra[:obj]] if mergedto.has_key? ra[:obj]

				# To find the indice of the subject and object
				idx_from = denotations.find_index{|d| d[:id] == ra[:subj]}
				idx_to   = denotations.find_index{|d| d[:id] == ra[:obj]}
				from = denotations[idx_from]
				to   = denotations[idx_to]

				from[:span] = [from[:span]] unless from[:span].respond_to?('push')
				to[:span]   = [to[:span]]   unless to[:span].respond_to?('push')

				# To merge the two spans (in the reverse order)
				from[:span] = to[:span] + from[:span]
				denotations.delete_at(idx_to)
				mergedto[ra[:obj]] = ra[:subj]
			end
		end
		relations.delete_if{|ra| ra[:pred] == '_lexicallyChainedTo'}

		return denotations, relations
	end

	def self.text2sentences(text)
		sentences = []
		sentence_spans = []

		b = 0
		e = 0

		until e.nil?
			b = text.index(/\S/, e)
			break if b.nil?
			e = text.index(/([.?!]\s|\n)/, b)
			if e.nil?
				sentences << text[b .. -1]
				sentence_spans << [b, text.length]
			else
				e += 1 unless text[e] == "\n"
				sentences << text[b ... e]
				sentence_spans << [b, e]
				b = e
			end
		end

		[sentences, sentence_spans]
	end

	def self.align_hdenotations_by_sentences!(hdenotations, str, rstr)
		tsentences, tsentence_spans = text2sentences(str)
		rsentences, rsentence_spans = text2sentences(rstr)

		compareDiff = Diff::LCS.sdiff(tsentences, rsentences)

		matchh = {}
		deltah = {}
		compareDiff.select{|c| c.action == '='}.each do |c|
			matchh[c.old_position] = c.new_position
			deltah[c.old_position] = rsentence_spans[c.new_position].first - tsentence_spans[c.old_position].first
		end

		messages = []
		slength = tsentence_spans.length
		new_spans = {}
		hdenotations.each do |d|
			b = d[:span][:begin]
			e = d[:span][:end]
			new_span = {begin:b, end:e}
			span_adjusted = false

			# find the **first** sentence whose end is bigger than the begin of the current span
			i = 0; i += 1 until i == slength || b <= tsentence_spans[i][1]
			unless i < slength && deltah[i].present?
				# messages << "An anotation is lost due to a substantial change to the text: #{d} (#{str[b ... e]})"
				# next
				return nil
			end
			unless b >= tsentence_spans[i][0]
				new_span[:begin] = tsentence_spans[i][0]
				span_adjusted = true
			end
			new_span[:begin] += deltah[i]

			# find the **first** sentence whose begin is bigger than the end of the current span
			i = 0; i += 1 until i == slength || e < tsentence_spans[i][0]
			# step back
			i -= 1
			unless deltah[i].present?
				# messages << "An anotation is lost due to a substantial change to the text: #{d} (#{str[b ... e]})"
				# next
				return nil
			end
			unless e <= tsentence_spans[i][1]
				new_span[:end] = tsentence_spans[i][1]
				span_adjusted = true
			end
			new_span[:end] += deltah[i]

			if span_adjusted
				messages << "The span is adjusted. Please check.\nOriginal:[#{str[b ... e]}]\nAdjusted:[#{rstr[new_span[:begin] ... new_span[:end]]}]"
			end
			new_spans[d[:id]] = new_span
		end

		hdenotations.each{|d| d[:span] = new_spans[d[:id]]}
		messages
	end

	def self.align_denotations_by_sentences!(denotations, str, rstr)
		tsentences, tsentence_spans = text2sentences(str)
		rsentences, rsentence_spans = text2sentences(rstr)

		compareDiff = Diff::LCS.sdiff(tsentences, rsentences)

		matchh = {}
		deltah = {}
		compareDiff.select{|c| c.action == '='}.each do |c|
			matchh[c.old_position] = c.new_position
			deltah[c.old_position] = rsentence_spans[c.new_position].first - tsentence_spans[c.old_position].first
		end

		messages = []
		slength = tsentence_spans.length
		new_spans = {}
		denotations.each do |d|
			b = d.begin
			e = d.end
			new_span = {begin:b, end:e}
			span_adjusted = false

			# find the **first** sentence whose end is bigger than the begin of the current span
			i = 0
			i += 1 until i == slength || b <= tsentence_spans[i][1]
			unless i < slength && deltah[i].present?
				# messages << "An anotation is lost due to a substantial change to the text: #{d} (#{str[b ... e]})"
				# next
				return nil
			end
			unless b >= tsentence_spans[i][0]
				new_span[:begin] = tsentence_spans[i][0]
				span_adjusted = true
			end
			new_span[:begin] += deltah[i]

			# find the **first** sentence whose begin is bigger than the end of the current span
			i = 0;
			i += 1 until i == slength || e < tsentence_spans[i][0]
			# step back
			i -= 1
			unless deltah[i].present?
				# messages << "An anotation is lost due to a substantial change to the text: #{d} (#{str[b ... e]})"
				# next
				return nil
			end
			unless e <= tsentence_spans[i][1]
				new_span[:end] = tsentence_spans[i][1]
				span_adjusted = true
			end
			new_span[:end] += deltah[i]

			if span_adjusted
				messages << "The span is adjusted. Please check.\nOriginal:[#{str[b ... e]}]\nAdjusted:[#{rstr[new_span[:begin] ... new_span[:end]]}]"
			end
			new_spans[d.hid] = new_span
		end

		denotations.each{|d| d.begin = new_spans[d.hid][:begin]; d.end = new_spans[d.hid][:end]}
		messages
	end

	def self.align_denotations!(denotations, str, rstr)
		return [] unless denotations.present? && str != rstr

		messages = []

		bads = denotations.select{|d| !(d.begin.kind_of?(Integer) && d.end.kind_of?(Integer) && d.begin >= 0 && d.end > d.begin && d.end <= str.length)}
		unless bads.empty?
			message = "Alignment cancelled. Invalid denotations found: "
			message += if bads.length > 5
				bads[0 ... 5].map{|d| d.to_s}.join(", ") + "..."
			else
				bads.map{|d| d.to_s}.join(", ")
			end
			raise message
		end

		aligner = TextAlignment::TextAlignment.new(rstr)
		aligner.align(str)
		aligner.transform_denotations!(denotations)

		bads = denotations.select{|d| !(d.begin.kind_of?(Integer) && d.end.kind_of?(Integer) && d.begin >= 0 && d.end > d.begin && d.end <= rstr.length)}
		unless bads.empty? # && aligner.similarity > 0.5
			message = "Alignment failed. Invalid transformations found: "
			message += if bads.length > 5
				bads[0 ... 5].map{|d| d.to_s}.join(", ") + "..."
			else
				bads.map{|d| d.to_s}.join(", ")
			end
			raise message
		end

		messages
	end

	# To align annotations, considering the span specification
	def self.align_annotations!(annotations, ref_text, aligner)
		return [] unless annotations[:denotations].present?

		messages = []
		begin
			# align_hdenotations
			denotations = annotations[:denotations]
			aligner.align(annotations[:text], denotations)

			denotations.replace(aligner.transform_hdenotations(denotations))

			unless aligner.lost_annotations.empty?
				messages << {
					sourcedb: annotations[:sourcedb],
					sourceid: annotations[:sourceid],
					body:"Alignment failed. Invalid denotations found after transformation",
					data:{
						block_alignment: aligner.block_alignment,
						lost_annotations: aligner.lost_annotations
					}
				}
			end
		rescue => e
			raise "[#{annotations[:sourcedb]}:#{annotations[:sourceid]}] #{e.message}"
		end
		annotations[:text] = ref_text
		annotations.delete_if{|k,v| !v.present?}
		messages
	end

	def self.prepare_annotations!(annotations, doc, options = {})
		if options[:span]
			span = options[:span]
			raise ArgumentError, "Annotations are in array, for which span cannot be specified." if annotations.is_a? Array
			raise ArgumentError, "The text of the span might be changed, which is not allowed when the span is explictely specified in the URL." if annotations[:text] != doc.get_text(span)

			if annotations[:denotations].present?
				annotations[:denotations].each do |d|
					d[:span][:begin] += span[:begin]
					d[:span][:end]   += span[:begin]
				end
			end
			annotations[:text] = doc.body
			[]
		else
			ref_text = doc.original_body.nil? ? doc.body : doc.original_body

			messages = if annotations.is_a? Array
				aligner = TextAlignment::TextAlignment.new(ref_text, options)
				annotations.map do |a|
					align_annotations!(a, ref_text, aligner)
				end.flatten
			else
				if annotations[:text] == ref_text
					[]
				else
					aligner = TextAlignment::TextAlignment.new(ref_text, options)
					align_annotations!(annotations, ref_text, aligner)
				end
			end
		end
	end

	def self.skey_of_denotation(d, obj = nil)
		obj.nil? ? "#{d[:span][:begin]}-#{d[:span][:end]}-#{d[:obj]}" : "#{d[:span][:begin]}-#{d[:span][:end]}-#{obj}"
	end

	def self.skey_of_attribute(a)
		"#{a[:subj]}-#{a[:pred]}-#{a[:obj]}"
	end

	# To resolve ID conflict
	def self.prepare_annotations_for_merging!(annotations, base_annotations)
		return annotations unless base_annotations[:denotations].present? && annotations[:denotations].present?
		base_denotations_idx = base_annotations[:denotations].inject({}){|idx, d| idx.merge!({skey_of_denotation(d) => d[:id]})}

		dup_denotations_idx = {}
		annotations[:denotations].each do |d|
			key = skey_of_denotation(d)
			dup_denotations_idx[d[:id]] = base_denotations_idx[key] if base_denotations_idx.has_key? key
		end

		annotations[:denotations].delete_if{|d| dup_denotations_idx.has_key? d[:id]}

		if annotations[:attributes].present?
			base_attributes_idx = base_annotations[:attributes].inject({}){|idx, a| idx.merge!({skey_of_attribute(a) => a[:id]})}
			annotations[:attributes].each do |a|
				s = a[:subj]
				a[:subj] = dup_denotations_idx[s] if dup_denotations_idx.has_key? s
				a[:obj] = '__delme__' if base_attributes_idx.has_key? skey_of_attribute(a)
			end
		end
		annotations[:attributes].delete_if{|a| a[:obj] == '__delme__'}

		if annotations[:relations].present?
			annotations[:relations].each do |r|
				s = r[:subj]
				r[:subj] = dup_denotations_idx[s] if dup_denotations_idx.has_key? s
				o = r[:obj]
				r[:obj] = dup_denotations_idx[o] if dup_denotations_idx.has_key? o
			end
		end

		if annotations[:modification].present?
			annotations[:modification].each do |m|
				s = m[:subj]
				m[:subj] = dup_denotations_idx[s] if dup_denotations_idx.has_key? s
			end
		end

		annotations
	end

	def self.add_source_project_color_coding!(annotations, color_coding = nil)
		color_coding ||= generate_source_project_color_coding(annotations)

		if color_coding.present?
			annotations[:config] = {} unless annotations.has_key? :config
			annotations[:config]["attribute types"] = [] unless annotations[:config].has_key? :attributes_types
			annotations[:config]["attribute types"] << color_coding

			annotations[:tracks].each_with_index do |track, i|
				track[:denotations].each do |d|
					track[:attributes] = [] unless track.has_key? :attributes
					track[:attributes] << {subj:d[:id], pred:'source', obj:track[:project]}
				end
			end
		end
		annotations
	end

	def self.generate_source_project_color_coding(annotations)
		if annotations[:tracks].present?
			source_type_values = []
			color_generator = ColorGenerator.new saturation: 0.7, lightness: 0.75
			annotations[:tracks].each_with_index do |track, i|
				source_type_values << {id:track[:project], color: '#' + color_generator.create_hex}
				source_type_values.last[:default] = true if i == 0
			end
			{pred:'source', "value type" => 'selection', values:source_type_values}
		else
			nil
		end
	end

end
