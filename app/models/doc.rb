class Doc < ActiveRecord::Base
	include Elasticsearch::Model
	include Elasticsearch::Model::Callbacks

	LIST_MAX_SIZE = 50

	settings index: {
		analysis: {
			analyzer: {
				standard_normalization: {
					tokenizer: :standard,
					filter: [:standard, :lowercase, :stop, :asciifolding, :snowball]
				}
			}
		}
	} do
		mappings do
			indexes :sourcedb, type: :keyword
			indexes :sourceid, type: :keyword
			indexes :body,     type: :text,  analyzer: :standard_normalization, index_options: :offsets

			# indexes :docs_projects, type: 'nested' do
			indexes :docs_projects do
				indexes :doc_id
				indexes :project_id
			end

			indexes :projects do
				indexes :id, type: :integer
			end
		end
	end

	SOURCEDBS = ["PubMed", "PMC", "FirstAuthors", 'GrayAnatomy', 'CORD-19']


	def self.search_docs(attributes = {})
		filter_condition = []
		filter_condition << {term: {'projects.id' => attributes[:project_id]}} if attributes[:project_id].present?
		filter_condition << {term: {'sourcedb' => attributes[:sourcedb]}} if attributes[:sourcedb].present?
		filter_condition << {term: {'sourceid' => attributes[:sourceid]}} if attributes[:sourceid].present?

		filter_phrase = {
			bool: {
				must: filter_condition
			}
		}

		docs = search(
			query: {
				bool: {
					must: {
						match: {
							body: {
								query: attributes[:body]
							}
						}
					},
					filter: filter_phrase
				}
			},
			highlight: {
				fields: {
					body: {}
				}
			}
		).page(attributes[:page]).per(attributes[:per])

		return docs
	end

	UserSourcedbSeparator = '@'
	after_save :expire_page_cache
	after_destroy :expire_page_cache
	# before_validation :attach_sourcedb_suffix
	include ApplicationHelper

	attr_accessor :username, :original_body, :text_aligner

	has_many :divisions, dependent: :destroy
	has_many :typesettings, dependent: :destroy

	has_many :denotations, dependent: :destroy
	has_many :blocks, dependent: :destroy

	has_many :subcatrels, class_name: 'Relation', :through => :denotations, :source => :subrels

	has_many :denotation_attributes, class_name: 'Attrivute', :through => :denotations, :source => :attrivutes

	has_many :catmods, class_name: 'Modification', :through => :denotations, :source => :modifications
	has_many :subcatrelmods, class_name: 'Modification', :through => :subcatrels, :source => :modifications

	has_many :project_docs, dependent: :destroy
	has_many :projects, through: :project_docs,
		:after_add => [:increment_docs_projects_counter, :update_es_doc],
		:after_remove => [:decrement_docs_projects_counter, :update_es_doc]

	validates :body,     presence: true
	validates :sourcedb, presence: true
	validates :sourceid, presence: true
	validates :sourceid, uniqueness: {scope: :sourcedb}
	
	scope :project_name, lambda{|project_name|
		{:joins => :projects,
			:conditions => ['projects.name =?', project_name]
		}
	}

	scope :simple_paginate, -> (page, per = 10) {
		page = page.nil? ? 1 : page.to_i
		offset = (page - 1) * per
		offset(offset).limit(per)
	}

	scope :relations_num, -> {
		joins("LEFT OUTER JOIN denotations ON denotations.doc_id = docs.id LEFT OUTER JOIN relations ON relations.subj_id = denotations.id AND relations.subj_type = 'Denotation'")
		.group('docs.id')
		.order('count(relations.id) DESC')
	}

	scope :projects_docs, lambda{|project_ids|
		{
			:joins => :projects,
			:conditions => ["docs_projects.project_id IN (?)", project_ids],
			:group => 'docs.id'
		}
	}

	scope :accessible_projects, lambda{|current_user_id|
		joins([:projects]).
		where('projects.accessibility = 1 OR projects.user_id = ?', current_user_id)
	}
	
	scope :sql, lambda{|ids|
		where('docs.id IN(?)', ids).
		order('docs.id ASC')
	}
	
	# scope :source_db_id, lambda{|order_key_method|
	#   # source id should cast as integer
	#   order_key_method ||= 'sourcedb ASC, sourceid_int ASC'
	#   where(['sourcedb NOT ? AND sourcedb != ? AND sourceid NOT ? AND sourceid != ?', nil, '', nil, ''])
	#   .select('*, COUNT(sourcedb) AS sourcedb_count, COUNT(sourceid) AS sourceid_count, CAST(sourceid AS INT) AS sourceid_int')
	#   .group(:sourcedb).group(:sourceid).order(order_key_method)
	# }
		
	scope :source_db_id, lambda{|order_key_method|
		order_key_method ||= 'sourcedb ASC, sourceid_int ASC'
		where(['sourcedb IS NOT ? AND sourceid IS NOT ?', nil, nil])
		.select('*, CAST(sourceid AS INT) AS sourceid_int')
		.group(:id).group(:sourcedb).group(:sourceid).order(order_key_method)
	}
	
	scope :same_sourcedb_sourceid, lambda{|sourcedb, sourceid|
		where(['sourcedb = ? AND sourceid = ?', sourcedb, sourceid])
	}
	
	scope :sourcedbs, -> { where(['sourcedb IS NOT ?', nil]) }

	scope :user_source_db, lambda{|username|
		where('sourcedb LIKE ?', "%#{UserSourcedbSeparator}#{username}")
	}
	
	# default sort order 
	#DefaultSort = [['sourceid', 'ASC']]
	def self.sort_order(project = nil)
		if project && project.small?
			"sourceid ASC"
		else
			nil
		end
	end

	def self.graph_uri
		"http://pubannotation.org/docs"
	end

	def graph_uri
		Rails.application.routes.url_helpers.doc_sourcedb_sourceid_show_url(sourcedb, sourceid, only_path: false)
	end

	def last_indexed_at(endpoint = nil)
		if endpoint.nil?
			endpoint = stardog(Rails.application.config.ep_url, user: Rails.application.config.ep_user, password: Rails.application.config.ep_password)
		end
		db = Rails.application.config.ep_database
		result = endpoint.query(db, "select ?o where {<#{graph_uri}> <http://www.w3.org/ns/prov#generatedAtTime> ?o}")
		begin
			DateTime.parse(result.body["results"]["bindings"].first["o"]["value"])
		rescue
			nil
		end
	end

	def update_es_doc(project)
		self.__elasticsearch__.index_document
	end

	def increment_docs_projects_counter(project)
		Doc.increment_counter(:projects_num, self.id)
	end

	def decrement_docs_projects_counter(project)
		Doc.decrement_counter(:projects_num, self.id)
		self.reload
	end

	def descriptor
		"#{sourcedb}:#{sourceid}"
	end

	def filename
		"#{sourcedb}-#{sourceid}"
	end

	def self.get_doc(docspec)
		if docspec[:sourcedb].present? && docspec[:sourceid].present?
			Doc.find_by_sourcedb_and_sourceid(docspec[:sourcedb], docspec[:sourceid])
		else
			nil
		end
	end

	def self.exist?(docspec)
		!self.get_doc(docspec).nil?
	end

	def self.hdoc_valid?(hdoc)
		return false unless hdoc[:text].present?
		return false unless hdoc[:sourcedb].present?
		return false unless hdoc[:sourceid].present?
		true
	end

	# returns {docs:..., messages:...}
	def self.sequence_docs(sourcedb, sourceids)
		raise ArgumentError, "sourcedb is empty" unless sourcedb.present?
		raise ArgumentError, "sourceids is empty" unless sourceids.present?

		sequencer = begin
			Sequencer.find(sourcedb)
		rescue ActiveRecord::ActiveRecordError => e
			nil
		end
		raise "Could not find the sequencer for the sourcedb: [#{sourcedb}]" unless sequencer.present?

		result = sequencer.get_docs(sourceids)

		invalid_docs = result[:docs].select{|doc| !Doc.hdoc_valid?(doc)}
		invalid_docs.each do |doc|
			result[:messages] << {sourcedb:sourcedb, sourceid:doc[:sourceid], body:"Invalid document entry."} unless Doc.hdoc_valid?(doc)
		end

		result[:docs] = result[:docs] - invalid_docs
		result
	end

	def self.store_hdoc(hdoc)
		hdoc[:text] = hdoc[:body] if !hdoc[:text] && hdoc[:body]

		doc = Doc.new(
			{
				body: hdoc[:text],
				sourcedb: hdoc[:sourcedb],
				sourceid: hdoc[:sourceid],
				source: hdoc[:source_url]
			}
		)

		doc.save!
		doc
	end

	def store_divisions(hdivisions)
		return [] if hdivisions.nil?

		divisions = hdivisions.map do |hdiv|
			Division.new(
				{
					doc_id: self.id,
					begin: hdiv[:span][:begin],
					end: hdiv[:span][:end],
					label: hdiv[:label]
				}
			)
		end

		r = Division.import divisions
		raise "Failed to save the divisions." unless r.failed_instances.empty?

		divisions
	end

	def store_typesettings(htypesettings)
		return [] if htypesettings.nil?

		typesettings = htypesettings.map do |hts|
			Typesetting.new(
				{
					doc_id: self.id,
					begin: hts[:span][:begin],
					end: hts[:span][:end],
					style: hts[:style]
				}
			)
		end

		r = Typesetting.import typesettings
		raise "Failed to save the typesettings." unless r.failed_instances.empty?

		typesettings
	end

	def self.store_hdocs(hdocs)
		docs_saved = []
		messages = []

		hdocs.each do |hdoc|
			ActiveRecord::Base.transaction do
				doc = store_hdoc(hdoc)
				doc.store_divisions(hdoc[:divisions]) if hdoc.has_key? :divisions
				doc.store_typesettings(hdoc[:typesettings]) if hdoc.has_key? :typesettings
				docs_saved << doc
			rescue => e
				messages << {sourcedb:hdoc[:sourcedb], sourceid:hdoc[:sourceid], body:e.message}
			end
		end

		[docs_saved, messages]
	end

	def self.sequence_and_store_docs(sourcedb, sourceids)
		result = sequence_docs(sourcedb, sourceids)
		docs_saved, messages = store_hdocs(result[:docs])
		[docs_saved, result[:messages] + messages]
	end

	def revise(new_hdoc)
		messages = []
		new_body = new_hdoc[:text] || new_hdoc[:body]

		if new_body == self.body
			unless self.divisions == new_hdoc[:divisions]
				self.divisions.destroy_all
				self.store_divisions(new_hdoc[:divisions])
			end

			unless self.typesettings == new_hdoc[:typesettings]
				self.typesettings.destroy_all
				self.store_typesettings(new_hdoc[:typesettings])
			end
		else
			_denotations = self.denotations
			_blocks = self.blocks
			messages += Annotation.align_denotations_and_blocks!(_denotations, _blocks, self.body, new_body)

			ActiveRecord::Base.transaction do
				self.divisions.destroy_all
				self.typesettings.destroy_all
				self.body = new_body
				self.save!
				self.store_divisions(new_hdoc[:divisions])
				self.store_typesettings(new_hdoc[:typesettings])
				_denotations.each{|d| d.save!}
				_blocks.each{|b| b.save!}
			end
		end

		messages
	end

	def self.uptodate(doc, new_hdoc = nil)
		sourcedb = doc.sourcedb
		sourceid = doc.sourceid

		new_hdoc ||= begin
			r = self.sequence_docs(sourcedb, [sourceid])
			raise "Could not sequence the document: #{sourcedb}:#{sourceid}" unless r[:docs].length == 1
			r[:docs].first
		end

		ActiveRecord::Base.transaction do
			doc.revise(new_hdoc)
		end
	end

	def reset_count_denotations
		ActiveRecord::Base.connection.exec_query "UPDATE docs SET (denotations_num) = (SELECT count(*) FROM denotations WHERE denotations.doc_id = #{id}) WHERE docs.id = #{id}"
	end

	def reset_count_relations
		ActiveRecord::Base.connection.exec_query "UPDATE docs SET (relations_num) = (SELECT count(*) FROM relations INNER JOIN denotations ON relations.subj_id = denotations.id AND relations.subj_type='Denotation' WHERE denotations.doc_id = #{id}) WHERE docs.id = #{id}"
	end

	def reset_count_modifications
		ActiveRecord::Base.connection.exec_query "UPDATE docs SET (modifications_num) = row((SELECT count(*) FROM modifications INNER JOIN denotations ON modifications.obj_id = denotations.id AND modifications.obj_type = 'Denotation' WHERE denotations.doc_id = #{id}) + (SELECT count(*) FROM modifications INNER JOIN relations on modifications.obj_id = relations.id AND modifications.obj_type = 'Relation' INNER JOIN denotations ON relations.subj_id = denotations.id AND relations.subj_type = 'Denotations' WHERE denotations.doc_id = #{id})) WHERE docs.id = #{id}"
	end

	def get_slices(max_size, span = nil)
		text = get_text(span)
		length = text.length
		if length > max_size
			slices = []
			_begin = 0
			while _begin + max_size < length
				subtext = text[_begin ... _begin + max_size]
				_end = subtext.rindex("\n")
				if _end.nil?
					raise RuntimeError, "Could not split the document."
				else
					_end += _begin
				end
				slices << {begin:_begin, end:_end}
				_begin = _end + 1
			end
			slices << {begin:_begin, end:length}
			unless span.nil?
				slices.each do |slice|
					slice[:begin] += span[:begin]
					slice[:end] += span[:begin]
				end
			end
			slices
		else
			span.nil? ? [nil] : [span]
		end
	end

	# returns relations count which belongs to project and doc
	def project_relations_num(project_id)
		count = Relation.project_relations_num(project_id, subcatrels)
	end
	
	# returns doc.relations count
	def relations_num
		subcatrels.size
	end
	
	def same_sourceid_denotations_num
		#denotation_doc_ids = Doc.where(:sourceid => self.sourceid).collect{|doc| doc.id}
		#Denotation.select('doc_id').where('doc_id IN (?)', denotation_doc_ids).size
		Doc.where(:sourceid => self.sourceid).sum('denotations_num')
	end

	def same_sourceid_relations_num
		Doc.where(:sourceid => self.sourceid).sum('relations_num')
	end
	
	def span(params)
		span = {:begin => params[:begin].to_i, :end => params[:end].to_i}
		body = self.body
		if params[:context_size].present?
			context_size = params[:context_size].to_i
			prev = {
				:begin => (span[:begin] < context_size)? 0 : span[:begin] - context_size,
				:end => span[:begin]
			}
			post = {
				:begin => span[:end],
				:end => (body.length - span[:end] < context_size)? body.length : span[:end] + context_size
			}
			prev_text = body[prev[:begin]...prev[:end]]
			post_text = body[post[:begin]...post[:end]]
		end
		return [prev_text, body[span[:begin]...span[:end]], post_text]
	end

	def spans_index(project_id = nil)
		self.get_denotations_hash(project_id).map{|d| {id:d[:id], span:d[:span], obj:self.span_url(d[:span])}}.uniq{|d| d[:span]}
	end

	def text(params)
		prev_text, span, next_text = self.span(params)
		[prev_text, span, next_text].compact.join('') 
	end

	def set_ascii_body
		self.original_body = self.body
		self.body = get_ascii_text(self.body)
	end

	def to_csv(params)
		focus, left, right = self.span(params) 
		CSV.generate(col_sep: "\t") do |csv|
			if params[:context_size].present?
				headers = %w(left focus right)
				values = [left, focus, right]
			else
				headers = %w(focus)
				values = [focus]
			end
			csv << headers
			csv << values 
		end
	end  

	def highlight_span(span)
		begin_pos = span[:begin].to_i
		end_pos = span[:end].to_i
		prev_text = self.body[0...begin_pos]
		focus_text = self.body[begin_pos...end_pos]
		next_text = self.body[end_pos..self.body.length]
		"<span class='context'>#{prev_text}</span><span class='highlight'>#{focus_text}</span><span class='context'>#{next_text}</span>"   
	end

	def get_project_count(span = nil)
		return self.projects.count if span.nil?

		# when the span is specified
		denotations.where("denotations.begin >= ? AND denotations.end <= ?", span[:begin], span[:end]).pluck(:project_id).uniq.count
	end

	def get_projects(span = nil)
		return self.projects if span.nil?

		# when the span is specified
		denotations.where("denotations.begin >= ? AND denotations.end <= ?", span[:begin], span[:end]).pluck(:project_id).uniq.collect{|pid| Project.find(pid)}
	end

	def get_annotation_hids(project_id, span = nil)
		denotation_hids = get_denotation_hids(project_id, span)
		return [] if denotation_hids.empty?

		base_ids = span.nil? ? nil : get_denotation_ids(project_id, span)

		relation_hids = get_relation_hids(project_id, base_ids)

		base_ids += get_relation_ids(project_id, base_ids) unless span.nil?

		attribute_hids = get_attribute_hids(project_id, base_ids)
		modification_hids = get_modification_hids(project_id, base_ids)

		denotation_hids + relation_hids + attribute_hids + modification_hids
	end

	# the first argument, project_id, may be a single id or an array of ids
	def get_denotations(project_id = nil, span = nil, context_size = nil, sort = false)
		_denotations = denotations.in_project(project_id).in_span(span)

		if span.present?
			b = span[:begin]
			unless context_size.nil?
				b -= context_size
				b = 0 if b < 0
			end
			_denotations.each{|d| d.begin -= b; d.end -= b}
		end

		if sort
			_denotations.sort{|d1, d2| (d1.begin <=> d2.begin).nonzero? || (d2.end <=> d1.end)}
		else
			_denotations
		end
	end

	# the first argument, project_id, may be a single id or an array of ids
	def get_blocks(project_id = nil, span = nil, context_size = nil, sort = false)
		_blocks = blocks.in_project(project_id).in_span(span)

		if span.present?
			b = span[:begin]
			unless context_size.nil?
				b -= context_size
				b = 0 if b < 0
			end
			_blocks.each{|a| a.begin -= b; a.end -= b}
		end

		if sort
			_blocks.sort{|b1, b2| (b1.begin <=> b2.begin).nonzero? || (b2.end <=> b1.end)}
		else
			_blocks
		end
	end

	# the first argument, project_id, may be a single id or an array of ids.
	def get_denotations_hash(project_id = nil, span = nil, context_size = nil, sort = false)
		self.get_denotations(project_id, span, context_size, sort).as_json
	end

	def get_blocks_hash(project_id = nil, span = nil, context_size = nil, sort = false)
		self.get_blocks(project_id, span, context_size, sort).as_json
	end

	# the first argument, project_id, may be a single id or an array of ids
	def get_denotation_ids(project_id = nil, span = nil)
		denotations.in_project(project_id).in_span(span).pluck(:id)
	end

	# the first argument, project_id, may be a single id or an array of ids
	def get_block_ids(project_id = nil, span = nil)
		blocks.in_project(project_id).in_span(span).pluck(:id)
	end

	# the first argument, project_id, may be a single id or an array of ids
	def get_denotation_hids(project_id = nil, span = nil)
		denotations.in_project(project_id).in_span(span).pluck(:hid)
	end

	# the first argument, project_id, may be a single id or an array of ids
	def get_denotations_hash_all(project_id = nil)
		annotations = {}
		annotations[:denotations] = get_denotations_hash(project_id)
		annotations[:target] = Rails.application.routes.url_helpers.doc_sourcedb_sourceid_show_url(sourcedb, sourceid, :only_path => false)
		annotations[:sourcedb] = sourcedb
		annotations[:sourceid] = sourceid
		annotations[:text] = body
		annotations
	end

	def get_denotations_count(project_id = nil, span = nil)
		if project_id.nil? && span.nil?
			denotations_num
		elsif span.nil?
			ProjectDoc.where(project_id:project_id, doc_id:id).pluck(:denotations_num).first
		else
			denotations.in_project(project_id).in_span(span).count
		end
	end

	def get_blocks_count(project_id = nil, span = nil)
		if project_id.nil? && span.nil?
			blocks_num
		elsif span.nil?
			ProjectDoc.where(project_id:project_id, doc_id:id).pluck(:blocks_num).first
		else
			blocks.in_project(project_id).in_span(span).count
		end
	end

	# project_id may be either a single project or a set of projects
	def get_relations(project_id = nil, base_ids = nil, sort = false)
		_relations = self.subcatrels.in_project(project_id).among_denotations(base_ids)
		if sort
			_relations.sort{|r1, r2| r1.id <=> r2.id}
		else
			_relations
		end
	end

	# the first argument, project, may be a project or an array of projects.
	def get_relations_hash(project_id = nil, base_ids = nil, sort = false)
		return [] if base_ids == []
		get_relations(project_id, base_ids, sort).as_json
	end

	# the first argument, project_id, may be a single id or an array of ids
	def get_relation_ids(project_id = nil, base_ids = nil)
		return [] if base_ids == []
		subcatrels.in_project(project_id).among_denotations(base_ids).pluck(:id)
	end

	# the first argument, project_id, may be a single id or an array of ids
	def get_relation_hids(project_id = nil, base_ids = nil)
		return [] if base_ids == []
		subcatrels.in_project(project_id).among_denotations(base_ids).pluck(:hid)
	end

	def get_attributes(project_id = nil, base_ids = nil)
		self.denotation_attributes.in_project(project_id).among_entities(base_ids)
	end

	def get_attributes_hash(project_id = nil, base_ids = nil)
		return [] if base_ids == []
		# continue if base_ids.nil? || base_ids.present?

		query = "SELECT attrivutes.hid AS id, attrivutes.pred AS pred, denotations.hid AS subj, attrivutes.obj AS obj FROM attrivutes INNER JOIN denotations ON attrivutes.subj_id = denotations.id WHERE denotations.doc_id = #{self.id}"

		# project condition
		unless project_id.nil?
			query += if project_id.respond_to?(:each)
				" AND attrivutes.project_id IN (#{project.map{|p| p.id}.join(', ')})"
			else
				" AND attrivutes.project_id = #{project_id}"
			end
		end

		# base_id condition
		unless base_ids.nil?
			query += " AND attrivutes.subj_id IN (#{base_ids.join(', ')})"
		end
	
		# sort!{|a1, a2| a1[:id] <=> a2[:id]}
		ActiveRecord::Base.connection.exec_query(query).to_a.collect{|a| a.symbolize_keys}
	end

	def get_attribute_ids(project_id = nil, base_ids = nil)
		self.denotation_attributes.in_project(project_id).among_entities(base_ids).pluck(:id)
	end

	def get_attribute_hids(project_id = nil, base_ids = nil)
		return [] if base_ids == []
		self.denotation_attributes.in_project(project_id).among_entities(base_ids).pluck(:hid)
	end

	def get_modifications(project_id = nil, base_ids = nil)
		self.catmods.in_project(project_id).among_entities(base_ids) + self.subcatrelmods.in_project(project_id).among_entities(base_ids)
		# sort{|m1, m2| m1.id <=> m2.id}
	end

	def get_modifications_hash(project_id = nil, base_ids = nil)
		return [] if base_ids == []
		self.catmods.in_project(project_id).among_entities(base_ids).as_json + self.subcatrelmods.in_project(project_id).among_entities(base_ids).as_json
	end

	def get_modification_ids(project_id = nil, base_ids = nil)
		return [] if base_ids == []
		self.catmods.in_project(project_id).among_entities(base_ids).pluck(:id) + self.subcatrelmods.in_project(project_id).among_entities(base_ids).pluck(:id)
	end

	def get_modification_hids(project_id = nil, base_ids = nil)
		return [] if base_ids == []
		self.catmods.in_project(project_id).among_entities(base_ids).pluck(:hid) + self.subcatrelmods.in_project(project_id).among_entities(base_ids).pluck(:hid)
	end

	def get_text(span = nil, context_size = nil)
		if span.present?
			b, e = 0, 0
			context_size ||= 0
			b = span[:begin] - context_size
			e = span[:end] + context_size
			b = 0 if b < 0
			e = body.length if e > body.length
			body[b...e]
		else
			body
		end
	end

	def get_divisions(span = nil, context_size = nil)
		if span.present?
			context_size ||= 0
			b = span[:begin] - context_size
			e = span[:end] + context_size
			b = 0 if b < 0
			e = body.length if e > body.length
			divisions.select{|t| t.begin >= b && t.end < e}.map{|t| t.begin -= b; t.end -= b; t.to_hash}
		else
			divisions.map{|t| t.to_hash}
		end
	end

	def get_typesettings(span = nil, context_size = nil)
		if span.present?
			context_size ||= 0
			b = span[:begin] - context_size
			e = span[:end] + context_size
			b = 0 if b < 0
			e = body.length if e > body.length
			typesettings.select{|t| t.begin >= b && t.end < e}.map{|t| t.begin -= b; t.end -= b; t.to_hash}
		else
			typesettings.map{|t| t.to_hash}
		end
	end

	def hdoc
		{
			text: body,
			sourcedb: sourcedb,
			sourceid: sourceid
		}
	end

	def to_hash(span = nil, context_size = nil)
		{
			target: Rails.application.routes.url_helpers.doc_sourcedb_sourceid_show_url(sourcedb, sourceid, only_path: false),
			sourcedb: sourcedb,
			sourceid: sourceid,
			source_url: source,
			text: get_text(span, context_size),
			divisions: get_divisions(span, context_size),
			typesettings: get_typesettings(span, context_size)
		}.reject{|k, v| k != :text && (v.nil? || v.empty?)}
	end

	def to_list_hash(doc_type)
		{
			sourcedb: sourcedb,
			sourceid: sourceid,
			url: Rails.application.routes.url_helpers.doc_sourcedb_sourceid_show_url(self.sourcedb, self.sourceid)
		}
	end

	def self.hash_to_tsv(docs)
		headers = docs.first.keys
		tsv = CSV.generate(col_sep:"\t") do |csv|
			# headers
			csv << headers
			docs.each do |doc|
				csv << doc.values
			end
		end
		return tsv
	end

	def self.to_tsv(docs, doc_type)
		headers = docs.first.to_list_hash(doc_type).keys
		tsv = CSV.generate(col_sep:"\t") do |csv|
			# headers
			csv << headers
			docs.each do |doc|
				doc_values = Array.new
				headers.each do |key|
					doc_values << doc.to_list_hash(doc_type)[key]
				end
				csv << doc_values
			end
		end
		return tsv
	end

	def hannotations(project = nil, span = nil, context_size = nil, options = nil)
		options ||= {}
		full = options[:full]

		annotations = self.to_hash(span, context_size)

		if project.present? && !project.respond_to?(:each)
			annotations.merge!(get_project_annotations(project, span, context_size, options))
		else
			projects = project.present? ? project : self.projects
			annotations[:tracks] = projects.inject([]) do |tracks, project|
				track = get_project_annotations(project, span, context_size, options)
				if full || track[:denotations].present?
					tracks << track
				else
					tracks
				end
			end
		end

		annotations
	end

	def get_project_annotations(project, span = nil, context_size = nil, options = {})
		options ||= {}
		sort_p = options[:sort]

		project_id = unless project.nil?
			project.respond_to?(:each) ? project.map{|p| p.id} : project.id
		end

		ids = nil

		hdenotations = get_denotations_hash(project_id, span, context_size, sort_p)
		ids = get_denotation_ids(project_id, span) unless span.nil?

		hblocks = get_blocks_hash(project_id, span, context_size, sort_p)
		ids += get_block_ids(project_id, span) unless span.nil?

		hrelations = get_relations_hash(project_id, ids, sort_p)
		ids += get_relation_ids(project_id, ids) unless span.nil?

		hattributes = get_attributes_hash(project_id, ids)
		hmodifications = get_modifications_hash(project_id, ids)

		if options[:discontinuous_span] == :bag
			hdenotations, hrelations = Annotation.bag_denotations(hdenotations, hrelations)
		end

		{project:project.name, denotations:hdenotations, blocks:hblocks, relations:hrelations, attributes:hattributes, modifications:hmodifications, namespaces:project.namespaces}.select{|k, v| v.present?}
	end

	def spans_projects(params)
		self_denotations = self.denotations
		if self_denotations.present?
			self_denotations.within_span({:begin => params[:begin], :end => params[:end]}).collect{|denotation| denotation.project}.uniq.compact
		end  
	end

	def self.sql_find(params, current_user, project)
		if params[:sql].present?
			current_user_id = current_user.present? ? current_user.id : nil
			sanitized_sql = sanitize_sql(params[:sql])
			results = self.connection.execute(sanitized_sql)
			if results.present?
				ids = results.collect{| result | result['id']}
				if project.present?
					# within project
					docs = self.accessible_projects(current_user_id).projects_docs([project.id]).sql(ids)
				else
					# within accessible projects
					docs = self.accessible_projects(current_user_id).sql(ids)
				end
			end       
		end
	end
	
	def updatable_for?(current_user)
		if current_user.present?
			(current_user.root? || created_by?(current_user))
		else
			false
		end
	end

	def self.sourcedb_public?(sourcedb)
		!sourcedb.include?(UserSourcedbSeparator)
	end

	def self.sourcedb_mine?(sourcedb, current_user)
		current_user.present? && sourcedb.include?("#{UserSourcedbSeparator}#{current_user.username}")
	end

	def created_by?(current_user)
		sourcedb.include?(':') && sourcedb.include?("#{UserSourcedbSeparator}#{current_user.username}")
	end

	def self.hdoc_normalize!(hdoc, current_user, no_personalize = false)
		raise RuntimeError, "You have to be logged in to create a document." unless current_user.present?

		unless hdoc[:body].present?
			if hdoc[:text].present?
				hdoc[:body] = hdoc[:text]
			else
				raise ArgumentError, "Text is missing."
			end
		end

		hdoc.delete(:text) if hdoc[:text].present?

		raise ArgumentError, "Text is missing." unless hdoc[:body].present?

		if no_personalize
			raise ArgumentError, "sourcedb is missing." unless hdoc[:sourcedb].present?
		else
			# personalize the sourcedb unless no_personalize
			if hdoc[:sourcedb].present?
				if hdoc[:sourcedb].include?(Doc::UserSourcedbSeparator)
					parts = hdoc[:sourcedb].split(Doc::UserSourcedbSeparator)
					raise ArgumentError, "'#{Doc::UserSourcedbSeparator}' is a special character reserved for separation of the username from a personal sourcedb name." unless parts.length == 2
					raise ArgumentError, "'#{parts[1]}' is not your username." unless parts[1] == current_user.username
				else
					hdoc[:sourcedb] += UserSourcedbSeparator + current_user.username
				end
			else
				hdoc[:sourcedb] = UserSourcedbSeparator + current_user.username
			end
		end

		# sourceid control
		unless hdoc[:sourceid].present?
			last_id = Doc.where(sourcedb: hdoc[:sourcedb]).pluck(:sourceid).max_by{|i| i.to_i}
			hdoc[:sourceid] = last_id.nil? ? '1' : last_id.next
		end

		hdoc
	end

	def attach_sourcedb_suffix
		if sourcedb.include?(UserSourcedbSeparator) == false && username.present?
			self.sourcedb = "#{sourcedb}#{UserSourcedbSeparator}#{username}"
		end
	end

	def self.count_per_sourcedb(current_user)
		docs_count_per_sourcedb = Doc.group(:sourcedb).count
		if current_user
			docs_count_per_sourcedb.delete_if do |sourcedb, doc_count|
				sourcedb.include?(Doc::UserSourcedbSeparator) && sourcedb.split(Doc::UserSourcedbSeparator)[1] != current_user.username
			end
		else
			docs_count_per_sourcedb.delete_if{|sourcedb, doc_count| sourcedb.include?(Doc::UserSourcedbSeparator)}
		end
		docs_count_per_sourcedb
	end

	def self.docs_count(current_user)
		docs_count_per_sourcedb = Doc.count_per_sourcedb(current_user)
		docs_count_per_sourcedb.values.inject(0){|sum, v| sum + v}
	end

	def expire_page_cache
		ActionController::Base.new.expire_fragment('sourcedb_counts')
		ActionController::Base.new.expire_fragment('docs_count')
	end

	def self.dummy(repeat_times)
		repeat_times.times do |t|
			create({sourcedb: 'FFIK', body: "body is #{ t }", sourceid: t.to_s})
		end
	end

	def self.update_numbers
		Doc.all.each do |d|
			d.update_numbers
		end
	end

	def update_numbers
		# numbers of this doc
		ActiveRecord::Base.connection.execute("update docs set denotations_num=#{denotations.count}, relations_num=#{subcatrels.count}, modifications_num=#{catmods.count + subcatrelmods.count} where id=#{id}")

		# numbers of each project_doc
		d_stat = denotations.group(:project_id).count
		r_stat = subcatrels.group("relations.project_id").count

		m_stat1 = catmods.group("modifications.project_id").count
		m_stat2 = subcatrelmods.group("modifications.project_id").count
		m_stat  = m_stat1.merge(m_stat2){|k,v1,v2| v1 + v2}

		pids = (d_stat.keys + r_stat.keys + m_stat.keys).uniq
		pids.each do |pid|
			d_num = d_stat[pid] || 0
			r_num = r_stat[pid] || 0
			m_num = m_stat[pid] || 0
			ActiveRecord::Base.connection.execute("update project_docs set denotations_num=#{d_num}, relations_num=#{r_num}, modifications_num=#{m_num} where doc_id=#{id} and project_id=#{pid}")
		end
	end

	def rdfizer_spans
		@rdfizer_spans ||= TAO::RDFizer.new(:spans)
	end

	# the first argument, project_id, may be a single id or an array of ids
	def get_spans_rdf(project_id, options = {})
		graph_uri_doc = self.graph_uri
		graph_uri_doc_spans = self.graph_uri + '/spans'

		doc_spans = self.get_denotations_hash_all(project_id)

		with_prefixes = options.has_key?(:with_prefixes) ? options[:with_prefixes] == true : false

		doc_spans_trig = ''

		if with_prefixes
			doc_spans_trig += rdfizer_spans.rdfize([doc_spans], {only_prefixes: true})
			doc_spans_trig += "@prefix oa: <http://www.w3.org/ns/oa#> .\n"
			doc_spans_trig += "@prefix prov: <http://www.w3.org/ns/prov#> .\n"
			doc_spans_trig += "\n"
		end

		if doc_spans && doc_spans[:denotations].present?
			doc_spans_ttl = rdfizer_spans.rdfize([doc_spans], {with_prefixes: false})
			doc_spans_trig += <<~HEREDOC
				<#{graph_uri_doc_spans}> rdf:type oa:Annotation ;
					oa:has_body <#{graph_uri_doc_spans}> ;
					oa:has_target <#{graph_uri_doc}> ;
					prov:generatedAtTime "#{DateTime.now.iso8601}"^^xsd:dateTime .

				GRAPH <#{graph_uri_doc_spans}>
				{
					#{doc_spans_ttl.gsub(/\n/, "\n\t")}
				}
			HEREDOC
		end

		doc_spans_trig
	end

	private

	def get_ascii_text(text)
		rewritetext = Utfrewrite.utf8_to_ascii(text)
		#rewritetext = text

		# escape non-ascii characters
		coder = HTMLEntities.new
		asciitext = coder.encode(rewritetext, :named)
		# restore back
		# greek letters
		asciitext.gsub!(/&[Aa]lpha;/, "alpha")
		asciitext.gsub!(/&[Bb]eta;/, "beta")
		asciitext.gsub!(/&[Gg]amma;/, "gamma")
		asciitext.gsub!(/&[Dd]elta;/, "delta")
		asciitext.gsub!(/&[Ee]psilon;/, "epsilon")
		asciitext.gsub!(/&[Zz]eta;/, "zeta")
		asciitext.gsub!(/&[Ee]ta;/, "eta")
		asciitext.gsub!(/&[Tt]heta;/, "theta")
		asciitext.gsub!(/&[Ii]ota;/, "iota")
		asciitext.gsub!(/&[Kk]appa;/, "kappa")
		asciitext.gsub!(/&[Ll]ambda;/, "lambda")
		asciitext.gsub!(/&[Mm]u;/, "mu")
		asciitext.gsub!(/&[Nn]u;/, "nu")
		asciitext.gsub!(/&[Xx]i;/, "xi")
		asciitext.gsub!(/&[Oo]micron;/, "omicron")
		asciitext.gsub!(/&[Pp]i;/, "pi")
		asciitext.gsub!(/&[Rr]ho;/, "rho")
		asciitext.gsub!(/&[Ss]igma;/, "sigma")
		asciitext.gsub!(/&[Tt]au;/, "tau")
		asciitext.gsub!(/&[Uu]psilon;/, "upsilon")
		asciitext.gsub!(/&[Pp]hi;/, "phi")
		asciitext.gsub!(/&[Cc]hi;/, "chi")
		asciitext.gsub!(/&[Pp]si;/, "psi")
		asciitext.gsub!(/&[Oo]mega;/, "omega")

		# symbols
		asciitext.gsub!(/&apos;/, "'")
		asciitext.gsub!(/&lt;/, "<")
		asciitext.gsub!(/&gt;/, ">")
		asciitext.gsub!(/&quot;/, '"')
		asciitext.gsub!(/&trade;/, '(TM)')
		asciitext.gsub!(/&rarr;/, ' to ')
		asciitext.gsub!(/&hellip;/, '...')

		# change escape characters
		asciitext.gsub!(/&([a-zA-Z]{1,10});/, '==\1==')
		asciitext.gsub!('==amp==', '&')

		asciitext
	end
end
