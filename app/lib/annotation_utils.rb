module AnnotationUtils
	include AnnotationsHelper

	class << self
		# To produce an array of annotations for export.
		# The initial row of the array to contain the headers
		def hash_to_array(annotations, textae_config = nil)
			array = []

			headers = ["Id", "Subject", "Object", "Predicate", "Lexical cue"]

			text = annotations[:text]
			lexical_cues = {}

			attrs_idx = {}
			attr_preds = []

			if annotations[:attributes].present?
				attrs = annotations[:attributes]

				attrs.each do |a|
					key = "#{a[:subj]}&#{a[:pred]}"
					attrs_idx[key] ||= []
					attrs_idx[key] << a[:obj]
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
						attr_values = attrs_idx["#{a[:id]}&#{pred}"]
						attr_values.nil? ? nil : attr_values.join('|')
					end
					array << [a[:id], spant, a[:obj], 'denotes', lexical_cues[a[:id]]] + attrs
				end
			end

			if annotations[:blocks].present?
				annotations[:blocks].each do |a|
					spans = a[:span].class == Array ? a[:span] : [a[:span]]
					lexical_cues[a[:id]] = spans.collect{|s| text[s[:begin]...s[:end]]}.join(' ').chomp
					spant = spans.collect{|s| "#{s[:begin]}-#{s[:end]}"}.to_csv.chomp
					attrs = attr_preds.collect do |pred|
						attr_values = attrs_idx["#{a[:id]}&#{pred}"]
						attr_values.nil? ? nil : attr_values.join('|')
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

		def hash_to_tsv(annotations, textae_config = nil)
			array = self.hash_to_array(annotations, textae_config)
			array[0][0] = '# ' + array[0][0]
			tsv = CSV.generate(col_sep:"\t") do |csv|
				array.each{|a| csv << a}
			end
			return tsv
		end

		def hash_to_dic_array(annotations)
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

		def dic_array_to_tsv(dic)
			dic[0][0] = '# ' + dic[0][0]
			CSV.generate(col_sep:"\t") do |csv|
				dic.each{|a| csv << a}
			end
		end

		def hash_to_dic(annotations)
			array = self.hash_to_dic_array(annotations)
			self.dic_array_to_tsv(array)
		end

		# normalize annotations passed by an HTTP call
		def normalize!(annotations, prefix = nil)
			raise ArgumentError, "annotations must be a hash." unless annotations.class == Hash
			raise ArgumentError, "annotations must include a 'text'"  unless annotations[:text].present?

			if annotations[:sourcedb].present?
				annotations[:sourcedb] = 'PubMed' if annotations[:sourcedb].downcase == 'pubmed'
				annotations[:sourcedb] = 'PMC' if annotations[:sourcedb].downcase == 'pmc'
				annotations[:sourcedb] = 'FirstAuthors' if annotations[:sourcedb].downcase == 'firstauthors'
			end

			text_length = annotations[:text].length

			d_ids = if annotations[:denotations].present?
								normalize_denotations!(annotations[:denotations], text_length)
								annotations[:denotations].collect{|a| a[:id]}
							else
								[]
							end

			b_ids = if annotations[:blocks].present?
								normalize_denotations!(annotations[:blocks], text_length, d_ids)
								annotations[:blocks].collect{|a| a[:id]}
							else
								[]
							end

			r_ids = if annotations[:relations].present?
								relations = annotations[:relations]
								raise ArgumentError, "'relations' must be an array." unless relations.class == Array
								relations.each{|a| a.symbolize_keys! if a.class == Hash }

								existing_ids = d_ids + b_ids + relations.collect{|a| a[:id]}.compact
								Relation.new_id_init(existing_ids)

								relations.each do |a|
									raise ArgumentError, "a relation must have 'subj', 'obj' and 'pred'." unless a[:subj].present? && a[:obj].present? && a[:pred].present?
									raise ArgumentError, "'subj' and 'obj' of a relation must reference to denotations or blocks: [#{a}]." unless ((d_ids.include? a[:subj]) && (d_ids.include? a[:obj])) || ((b_ids.include? a[:subj]) && (b_ids.include? a[:obj]))

									a[:id] = Relation.new_id unless a.has_key? :id
								end

								relations.collect{|a| a[:id]}
							else
								[]
							end

			# chaining is the default model of PubAnnotation
			# annotations = Annotation.chain_spans(annotations)

			dbr_ids = d_ids + b_ids + r_ids

			a_ids = if annotations[:attributes].present?
								attributes = annotations[:attributes]
								raise ArgumentError, "'attributes' must be an array." unless attributes.class == Array
								attributes.each {|a| a.symbolize_keys! if a.class == Hash }

								existing_ids = dbr_ids + attributes.collect{|a| a[:id]}.compact
								Attrivute.new_id_init(existing_ids)

								attributes.each do |a|
									# TODO: to remove the following line after TextAE is updated.
									a[:obj] = true unless a[:obj].present?

									raise ArgumentError, "An attribute must have 'subj', 'obj' and 'pred'." unless a[:subj].present? && a[:obj].present? && a[:pred].present?
									raise ArgumentError, "The 'subj' of an attribute must reference to a denotation or a relation: [#{a}]." unless dbr_ids.include? a[:subj]

									a[:id] = Attrivute.new_id unless a.has_key? :id
								end
							else
								[]
							end

			if annotations[:modifications].present?
				modifications = annotations[:modifications]
				raise ArgumentError, "'modifications' must be an array." unless modifications.class == Array
				modifications.each {|a| a.symbolize_keys! if a.class == Hash }

				existing_ids = dr_ids + a_ids + modifications.collect{|a| a[:id]}.compact
				Modification.new_id_init(existing_ids)

				modifications.each do |a|
					raise ArgumentError, "A modification must have 'pred' and 'obj'." unless a[:pred].present? && a[:obj].present?
					raise ArgumentError, "The 'obj' of a modification must reference to a denotation or a relation: [#{a}]." unless dr_ids.include? a[:obj]

					a[:id] = Modification.new_id unless a.has_key? :id
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

		def normalize_denotations!(denotations, text_length, existing_ids = [])
			if denotations.present?
				raise ArgumentError, "'denotations' must be an array." unless denotations.class == Array

				denotations.each { |d| d.deep_symbolize_keys! if d.class == Hash }

				existing_ids += denotations.collect{|d| d[:id]}.compact
				Denotation.new_id_init(existing_ids)

				denotations.each do |a|
					## object
					raise ArgumentError, "a denotation must have an 'obj'." unless a[:obj].present?

					## span
					if a[:span].present?
						if a[:span].class == Array
							a[:span].each{|s| validate_span(a, s, text_length)}
						else
							validate_span(a, a[:span], text_length)
						end
					else
						if a[:begin].present? && a[:end].present?
							a[:span] = {begin: a[:begin], end: a[:end]}
						else
							raise ArgumentError, "a denotation must have a 'span' or a pair of 'begin' and 'end'."
						end
					end

					## id
					a[:id] = Denotation.new_id unless a.has_key? :id
				end
			end
		end

		def validate_span(a, span, text_length)
			raise ArgumentError, "The span of a denotation must have both 'begin' and 'end': #{a}" unless span[:begin].present? && span[:end].present?
			raise ArgumentError, "The begin and end of a span must have integer values: #{a}" unless (span[:begin].is_a? Integer) && (span[:end].is_a? Integer)
			raise ArgumentError, "the begin value must be between 0 and #{text_length - 1} (text length - 1): #{a}" unless span[:begin].between?(0, text_length - 1)
			raise ArgumentError, "the end value must be between 1 and #{text_length} (text length): #{a}" unless span[:end].between?(1, text_length)
			raise ArgumentError, "the end value must be bigger than the begin value: #{a}" unless span[:begin] < span[:end]
		end

		def chain_spans(annotations)
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

		def bag_spans(annotations)
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

		def text2sentences(text)
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

		def align_hdenotations_by_sentences!(hdenotations, str, rstr)
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

		def align_denotations_and_blocks!(denotations, blocks, str, rstr)
			return [] unless denotations.present? && str != rstr

			messages = []

			bads = denotations.select{|d| !d.range_valid?(str.length)}
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
			aligner.transform_denotations!(blocks)

			bads = denotations.select{|d| !d.range_valid?(rstr.length)}
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
		def align_annotations!(annotations, ref_text, aligner)
			return [] unless annotations[:denotations].present? || annotations[:blocks].present?

			# align_hdenotations
			denotations = annotations[:denotations] || []
			blocks = annotations[:blocks] || []

			begin
				aligner.align(annotations[:text], denotations + blocks)
			rescue => e
				raise "[#{annotations[:sourcedb]}:#{annotations[:sourceid]}] #{e.message}"
			end

			annotations[:text] = ref_text
			annotations[:denotations] = aligner.transform_hdenotations(denotations)
			annotations[:blocks] = aligner.transform_hdenotations(blocks)
			annotations.delete_if{|k,v| !v.present?}

			if aligner.lost_annotations.present?
				[{
					 sourcedb: annotations[:sourcedb],
					 sourceid: annotations[:sourceid],
					 body:"Alignment failed. Invalid denotations found after transformation",
					 data:{
						 block_alignment: aligner.block_alignment,
						 lost_annotations: aligner.lost_annotations
					 }
				 }]
			else
				[]
			end
		end

		def prepare_annotations!(annotations, doc, options = {})
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
				if annotations[:blocks].present?
					annotations[:blocks].each do |d|
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

		def skey_of_denotation(d, obj = nil)
			obj.nil? ? "#{d[:span][:begin]}-#{d[:span][:end]}-#{d[:obj]}" : "#{d[:span][:begin]}-#{d[:span][:end]}-#{obj}"
		end

		def skey_of_attribute(a)
			"#{a[:subj]}-#{a[:pred]}-#{a[:obj]}"
		end

		# To resolve ID conflict
		def prepare_annotations_for_merging!(annotations, base_annotations)
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

		def add_source_project_color_coding!(annotations, color_coding = nil)
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

		def generate_source_project_color_coding(annotations)
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

		def analyse(annotations)
			denotations = annotations[:denotations]
			denotations.sort!{|d1, d2| (d1[:span][:begin] <=> d2[:span][:begin]).nonzero? || (d2[:span][:end] <=> d1[:span][:end])}

			# Embeddings
			embeddingh = {}
			(1 ... denotations.length).each do |c|
				e = find_embedding(denotations, c, embeddingh)
				embeddingh[c] = e if e.present?
			end
			embeddings = embeddingh.to_a

			# Boundary Crossings
			bcrossings = []
			(0 ... denotations.length).each do |c|
				n = c + 1
				while n < denotations.length && denotations[n][:span][:begin] < denotations[c][:span][:end]
					bcrossings << [c, n] if bcrossing?(denotations[c], denotations[n])
					n += 1
				end
			end

			# Duplicate labels
			duplabels = []
			(1 ... denotations.length).each do |c|
				p = c - 1
				if duplicate?(denotations[c], denotations[p])
					last_dup = duplabels.empty? ? nil : duplabels[-1]
					if last_dup&.include?(p)
						last_dup << c
					else
						duplabels << [p, c]
					end
				end
			end

			embeddings.map!{|e| {sourcedb:annotations[:sourcedb], sourceid:annotations[:sourceid], embedded:denotations[e.first][:id], embedding:denotations[e.last][:id]}}
			bcrossings.map!{|c| {sourcedb:annotations[:sourcedb], sourceid:annotations[:sourceid], left:denotations[c.first][:id], right:denotations[c.second][:id]}}
			duplabels.map!{|d| {sourcedb:annotations[:sourcedb], sourceid:annotations[:sourceid], ids:d.map{|id| denotations[id][:id]}}}

			{embeddings:embeddings, bcrossings:bcrossings, duplabels:duplabels}
		end

		private

		def find_embedding(denotations, c, embeddingh)
			return nil unless c > 0

			p = c - 1
			if embedding?(denotations[c], denotations[p])
				p
			else
				pe = embeddingh[p]
				while pe.present?
					return pe if embedding?(denotations[c], denotations[pe])
					pe = embeddingh[pe]
				end
				nil
			end
		end

		# assume that entries are all sorted
		def embedding?(current, previous)
			current[:span][:end] <= previous[:span][:end] && ((current[:span][:begin] != previous[:span][:begin]) || (current[:span][:end] != previous[:span][:end]))
		end

		def bcrossing?(current, nnext)
			(current[:span][:end] > nnext[:span][:begin]) && (current[:span][:end] < nnext[:span][:end])
		end

		def duplicate?(current, previous)
			(current[:span][:begin] == previous[:span][:begin]) && (current[:span][:end] == previous[:span][:end])
		end
	end
end
