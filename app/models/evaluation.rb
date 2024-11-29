class Evaluation < ActiveRecord::Base
	belongs_to :study_project, class_name: 'Project'
	belongs_to :reference_project, class_name: 'Project'
	belongs_to :evaluator

	validates :user_id, presence: true
	validates :study_project, presence: true
	validates :reference_project, presence: true
	validates :evaluator, presence: true
	validates_each :reference_project do |record, attr, value|
		unless value.nil?
			if value == record.study_project
				record.errors.add(attr, "must be a different one from the study_project.")
			else
				docs_std = record.study_project.docs
				docs_ref = value.docs
				docs_common = docs_std & docs_ref
				record.errors.add(attr, "has no shared document with the study project.") if docs_common.length == 0
			end
		end
	end

	scope :accessible, -> (current_user) {
		if current_user.present?
			if current_user.root?
			else
				where('evaluations.is_public = ? OR evaluations.user_id = ?', true, current_user.id)
			end
		else
			where('evaluations.is_public = true')
		end
	}

	def changeable?(current_user)
		current_user.present? && (current_user.root? || current_user == study_project.user)
	end

	def obtain
		raise RuntimeError, "The method is valid only when the evaluator is a web service."unless evaluator.access_type == 2
		raise RuntimeError, "The URL of the evaluation web service is not specified." unless evaluator.url.present?

		annotations_col = study_project.docs.collect{|doc| doc.hannotations(study_project, nil, nil)}
		@hresult = make_request(evaluator.url, annotations_col)
		update_attribute(:result, JSON.generate(@hresult))

		@hresult
	end

	def make_request(url, annotations_col)
		response = begin
			RestClient::Request.execute(method: :post, url: url, payload: annotations_col.to_json, max_redirects: 0, headers:{content_type: 'application/json; charset=utf8', accept: :json}, verify_ssl: false)
		rescue => e
			raise "The evaluation service reported a problem: #{e.message}"
		end

		begin
			JSON.parse response, :symbolize_names => true
		rescue => e
			raise RuntimeError, "Received a non-JSON object: [#{response}]"
		end
	end

	def hresult
		@hresult ||= JSON.parse result, :symbolize_names => true
	end

	def true_positives(type = nil, element = nil, sort_key = nil)
		tps = hresult[:true_positives] || []
		tps = tps.select{|c| c[:type] == type} unless type.nil?
		element_key = type == :relation ? :pred : :obj
		tps = tps.select{|c| c[:study][element_key] == element} unless element.nil?
		if sort_key.present?
			tps = case sort_key
			when :text
				count_hash = begin
					texts = tps.collect{|fn| fn[:study][:text]}
					texts.uniq.map{|t| [t, texts.count(t)]}.to_h
				end
				tps.sort_by do |fn|
					text = fn[:study][:text]
					[-count_hash[text], text]
				end
			when :doc
				count_hash = begin
					docspecs = tps.collect{|fn| fn[:sourcedb] + ':' + fn[:sourceid]}
					docspecs.uniq.map{|d| [d, docspecs.count(d)]}.to_h
				end
				tps.sort_by do |fn|
					docspec = fn[:sourcedb] + ':' + fn[:sourceid]
					[-count_hash[docspec], docspec]
				end
			when :label
				count_hash = begin
					labels = tps.collect{|fn| fn[:study][element_key]}
					labels.uniq.map{|l| [l, labels.count(l)]}.to_h
				end
				tps.sort_by do |fn|
					label = fn[:study][element_key]
					[-count_hash[label], label]
				end
			end
		end
		tps
	end

	def false_positives(type = nil, element = nil, sort_key = nil)
		fps = hresult[:false_positives] || []
		fps = fps.select{|c| c[:type] == type} unless type.nil?
		element_key = type == :relation ? :pred : :obj
		fps = fps.select{|c| c[:study][element_key] == element} unless element.nil?
		if sort_key.present?
			fps = case sort_key
			when :text
				count_hash = begin
					texts = fps.collect{|fn| fn[:study][:text]}
					texts.uniq.map{|t| [t, texts.count(t)]}.to_h
				end
				fps.sort_by do |fn|
					text = fn[:study][:text]
					[-count_hash[text], text]
				end
			when :doc
				count_hash = begin
					docspecs = fps.collect{|fn| fn[:sourcedb] + ':' + fn[:sourceid]}
					docspecs.uniq.map{|d| [d, docspecs.count(d)]}.to_h
				end
				fps.sort_by do |fn|
					docspec = fn[:sourcedb] + ':' + fn[:sourceid]
					[-count_hash[docspec], docspec]
				end
			when :label
				count_hash = begin
					labels = fps.collect{|fn| fn[:study][element_key]}
					labels.uniq.map{|l| [l, labels.count(l)]}.to_h
				end
				fps.sort_by do |fn|
					label = fn[:study][element_key]
					[-count_hash[label], label]
				end
			end
		end
		fps
	end

	def false_negatives(type = nil, element = nil, sort_key = nil)
		fns = hresult[:false_negatives] || []
		fns = fns.select{|c| c[:type] == type} unless type.nil?
		element_key = type == :relation ? :pred : :obj
		fns = fns.select{|c| c[:reference][element_key] == element} unless element.nil?
		if sort_key.present?
			fns = case sort_key
			when :text
				count_hash = begin
					texts = fns.collect{|fn| fn[:reference][:text]}
					texts.uniq.map{|t| [t, texts.count(t)]}.to_h
				end
				fns.sort_by do |fn|
					text = fn[:reference][:text]
					[-count_hash[text], text]
				end
			when :doc
				count_hash = begin
					docspecs = fns.collect{|fn| fn[:sourcedb] + ':' + fn[:sourceid]}
					docspecs.uniq.map{|d| [d, docspecs.count(d)]}.to_h
				end
				fns.sort_by do |fn|
					docspec = fn[:sourcedb] + ':' + fn[:sourceid]
					[-count_hash[docspec], docspec]
				end
			when :label
				count_hash = begin
					labels = fns.collect{|fn| fn[:reference][element_key]}
					labels.uniq.map{|l| [l, labels.count(l)]}.to_h
				end
				fns.sort_by do |fn|
					label = fn[:reference][element_key]
					[-count_hash[label], label]
				end
			end
		end
		fns
	end

	def true_positives_csv(type = nil, element = nil, sort_key = nil)
		element_key = type == :relation ? :pred : :obj

		tps = true_positives(type, element, sort_key)
		tps.map{|tp| []}

		column_names = %w{sourcedb sourceid begin_offset end_offset text label show_link}

		CSV.generate(col_sep: "\t") do |csv|
			csv << column_names
			tps.each do |tp|
				csv << [
					tp[:sourcedb],
					tp[:sourceid],
					tp[:study][:span][:begin],
					tp[:study][:span][:end],
					tp[:study][:text],
					tp[:study][element_key],
					Rails.application.routes.url_helpers.doc_sourcedb_sourceid_span_annotations_list_view_url(tp[:sourcedb], tp[:sourceid], tp[:study][:span][:begin], tp[:study][:span][:end], {projects:"#{study_project.name},#{reference_project.name}", full:true, context_size:10})
				]
			end
		end
	end

	def false_positives_csv(type = nil, element = nil, sort_key = nil)
		element_key = type == :relation ? :pred : :obj

		fps = false_positives(type, element, sort_key)
		fps.map{|fp| []}

		column_names = %w{sourcedb sourceid begin_offset end_offset text label show_link}

		CSV.generate(col_sep: "\t") do |csv|
			csv << column_names
			fps.each do |fp|
				csv << [
					fp[:sourcedb],
					fp[:sourceid],
					fp[:study][:span][:begin],
					fp[:study][:span][:end],
					fp[:study][:text],
					fp[:study][element_key],
					Rails.application.routes.url_helpers.doc_sourcedb_sourceid_span_annotations_list_view_url(fp[:sourcedb], fp[:sourceid], fp[:study][:span][:begin], fp[:study][:span][:end], {projects:"#{study_project.name},#{reference_project.name}", full:true, context_size:10})
				]
			end
		end
	end

	def false_negatives_csv(type = nil, element = nil, sort_key = nil)
		element_key = type == :relation ? :pred : :obj

		fps = false_negatives(type, element, sort_key)
		fps.map{|fp| []}

		column_names = %w{sourcedb sourceid begin_offset end_offset text label show_link}

		CSV.generate(col_sep: "\t") do |csv|
			csv << column_names
			fps.each do |fp|
				csv << [
					fp[:sourcedb],
					fp[:sourceid],
					fp[:reference][:span][:begin],
					fp[:reference][:span][:end],
					fp[:reference][:text],
					fp[:reference][element_key],
					Rails.application.routes.url_helpers.doc_sourcedb_sourceid_span_annotations_list_view_url(fp[:sourcedb], fp[:sourceid], fp[:reference][:span][:begin], fp[:reference][:span][:end], {projects:"#{study_project.name},#{reference_project.name}", full:true, context_size:10})
				]
			end
		end
	end
end
