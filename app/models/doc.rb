class Doc < ActiveRecord::Base
	include Doc::AnnotationCounts
	include Doc::Import
	include Doc::Revision
	include Doc::Media
	include Doc::TextOperations
	include Doc::Serialization
	include Doc::Rdf
	include Doc::Search
	include Doc::ElasticsearchIndexable
	include TermSearchConcern
	include PaginateConcern

	SOURCEDBS = ['PubMed', 'PMC', 'GrayAnatomy']

	UserSourcedbSeparator = '@'

	attr_accessor :username, :text_aligner

	has_many :divisions, dependent: :destroy
	# Paragraph is a kind of division which has label 'p'.
	has_many :paragraphs

	has_many :typesettings, dependent: :destroy

	has_many :denotations, dependent: :destroy
	has_many :blocks, dependent: :destroy
	# Sentence is a kind of block which has obj 'sentence'.
	has_many :sentences

	has_many :relations, dependent: :destroy
	has_many :attrivutes, dependent: :destroy

	has_many :project_docs, dependent: :destroy
	has_many :projects, through: :project_docs,
		:after_add => [:increment_docs_projects_counter, :queue_es_project_add],
		:after_remove => [:decrement_docs_projects_counter, :queue_es_project_remove]

	# As LF, so char offsets into the body (e.g. denotations') don't depend on how it was submitted.
	normalizes :body, with: ->(body) { body.gsub("\r\n", "\n") }

	validates :body,     presence: true
	validates :sourcedb, presence: true
	validates :sourceid, presence: true
	validates :sourceid, uniqueness: {scope: :sourcedb}

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

	def self.search_by_active_record(page, per, project = nil, sourcedb = nil,
																	 sort_key = nil, sort_direction = nil, is_randomize = false)
		docs = all
		docs = docs.joins(:projects).where(projects: { id: project.id }) if project.present?
		docs = docs.where(sourcedb: sourcedb) if sourcedb.present?

		sort_order = if sort_key.present? && sort_direction.present?
									 "#{sort_key} #{sort_direction}"
								 else
									 default_sort_order_for project
								 end
		sort_order = [sort_order, Arel.sql('random()')] if is_randomize

		docs.order(sort_order).simple_paginate(page, per)
	end

	def self.search_by_term(user, base_project_name, terms, predicates, projects, page, per)
		base_project = Project.accessible(user).find_by!(name: base_project_name) if base_project_name.present?
		docs = base_project.present? ? base_project.docs : Doc.all

		if terms.present?
			docs = docs.with_terms terms,
														 user,
														 predicates,
														 projects
		end

		docs.select('sourcedb', 'sourceid')
				.simple_paginate(page, per)
				.map(&:to_list_hash)
	end

	def increment_docs_projects_counter(project)
		Doc.increment_counter(:projects_num, self.id)
	end

	def decrement_docs_projects_counter(project)
		Doc.decrement_counter(:projects_num, self.id)
		self.reload
	end

	def spec
		{sourcedb:sourcedb, sourceid:sourceid}
	end

	def descriptor
		"#{sourcedb}:#{sourceid}"
	end

	def filename
		"#{sourcedb}-#{sourceid}"
	end

	def self.parse_filename(_filename)
		parts = _filename.split('-')
		raise ArgumentError, "The filename of a txt file has to be in the form of 'sourcedb-sourceid': #{_filename}" unless parts.length > 1
		sourceid = parts.pop
		sourcedb = parts.join('-')
		[sourcedb, sourceid]
	end

	def self.get_doc(docspec)
		if docspec[:sourcedb].present? && docspec[:sourceid].present?
			Doc.find_by_sourcedb_and_sourceid(docspec[:sourcedb], docspec[:sourceid])
		else
			nil
		end
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

	# returns relations count which belongs to project and doc
	def project_relations_num(project_id)
		ActiveRecord::Base.connection.select_value "SELECT relations_num FROM project_docs WHERE project_id=#{project_id} AND doc_id=#{id}"
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

	# ToDo: to move to the ProjectDoc class
	def get_annotation_hids(project_id, span = nil)
		denotation_hids = denotations.in_project_and_span(project_id, span).pluck(:hid)
		block_hids = blocks.in_project_and_span(project_id, span).pluck(:hid)

		return [] if denotation_hids.empty? && block_hids.empty?

		denotation_ids = denotations.in_project_and_span(project_id, span).pluck(:id)
		block_ids = blocks.in_project_and_span(project_id, span).pluck(:id)

		base_ids = span.nil? ? nil : denotation_ids + block_ids

		relation_hids = get_relation_hids(project_id, base_ids)

		base_ids += get_relation_ids(project_id, base_ids) unless span.nil?

		attribute_hids = get_attribute_hids(project_id, base_ids)

		denotation_hids + block_hids + relation_hids + attribute_hids
	end

	def get_denotations_count(project_id = nil, span = nil)
		if project_id.nil? && span.nil?
			denotations_num
		elsif span.nil?
			ActiveRecord::Base.connection.select_value <<~SQL.squish
				SELECT denotations_num
				FROM project_docs
				WHERE project_id=#{project_id}
				AND doc_id=#{id}
			SQL
		else
			denotations.in_project_and_span(project_id, span).count
		end
	end

	def get_blocks_count(project_id = nil, span = nil)
		if project_id.nil? && span.nil?
			blocks_num
		elsif span.nil?
			ActiveRecord::Base.connection.select_value <<~SQL.squish
				SELECT blocks_num
				FROM project_docs
				WHERE project_id=#{project_id}
				AND doc_id=#{id}
			SQL
		else
			blocks.in_project_and_span(project_id, span).count
		end
	end

	def get_relations_count(project_id = nil, span = nil)
		if project_id.nil? && span.nil?
			relations_num
		elsif span.nil?
			ActiveRecord::Base.connection.select_value <<~SQL.squish
				SELECT relations_num
				FROM project_docs
				WHERE project_id=#{project_id}
				AND doc_id=#{id}
			SQL
		else
			scope = relations
				.joins("INNER JOIN denotations AS subj_d ON subj_d.id = relations.subj_id AND relations.subj_type = 'Denotation'")
				.joins("INNER JOIN denotations AS obj_d  ON obj_d.id  = relations.obj_id  AND relations.obj_type  = 'Denotation'")
				.where('subj_d.begin >= :b AND subj_d."end" <= :e', b: span[:begin], e: span[:end])
				.where('obj_d.begin  >= :b AND obj_d."end"  <= :e', b: span[:begin], e: span[:end])
			scope = scope.where(project_id: project_id) if project_id
			scope.count
		end
	end

	# the first argument, project_id, may be a single id or an array of ids
	def get_relation_ids(project_id = nil, base_ids = nil)
		return [] if base_ids == []
		relations.in_project(project_id).among_denotations(base_ids).pluck(:id)
	end

	# the first argument, project_id, may be a single id or an array of ids
	def get_relation_hids(project_id = nil, base_ids = nil)
		return [] if base_ids == []
		relations.in_project(project_id).among_denotations(base_ids).pluck(:hid)
	end

	def get_attribute_hids(project_id = nil, base_ids = nil)
		return [] if base_ids == []
		attrivutes.in_project(project_id).among_entities(base_ids).pluck(:hid)
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

	# ToDo: del me in favor of the identical one in the ProjectDoc class
	def hannotations(projects, span, context_size,
									 terms: nil, predicates: nil,
									 is_sort: false, is_full: false, is_bag_denotations: false)
		annotations_hash = if projects.present?
			AnnotationsHash.new self,
								projects,
								span,
								context_size,
								terms,
								predicates,
								is_sort,
								is_full,
								is_bag_denotations,
								projects.respond_to?(:each) # When project is single, return annotations without track.
		else
			AnnotationsHash.new self,
								nil,
								span,
								context_size,
								terms,
								predicates,
								is_sort,
								is_full,
								is_bag_denotations,
								true
		end

		annotations_hash.to_hash
	end

	def updatable_for?(current_user)
		if current_user.present?
			(current_user.root? || created_by?(current_user))
		else
			false
		end
	end

	# Returns the personalized sourcedb for a given sourcedb and username
	# Example: personalize_sourcedb("PMC", "alice") => "PMC@alice"
	def self.personalize_sourcedb(sourcedb, username)
		return nil unless sourcedb.present? && username.present?
		"#{sourcedb}#{UserSourcedbSeparator}#{username}"
	end

	def created_by?(current_user)
		sourcedb.include?(':') && sourcedb.include?("#{UserSourcedbSeparator}#{current_user.username}")
	end

	def self.hdoc_normalize!(hdoc, current_user, no_personalize = false)
		raise SecurityError, "You have to be logged in to create a document." unless current_user.present?

		# body = text
		hdoc[:body] ||= hdoc[:text] || raise(ArgumentError, "Text is missing.")
		hdoc.delete(:text) if hdoc[:text].present?

		# sourcedb, to be personalized
		if no_personalize
			raise ArgumentError, "For admin, the 'sourcedb' cannot be automatically generated." unless hdoc[:sourcedb].present?
		else
			# personalize the sourcedb unless no_personalize
			if hdoc[:sourcedb].present?
				if hdoc[:sourcedb].include?(Doc::UserSourcedbSeparator)
					parts = hdoc[:sourcedb].split(Doc::UserSourcedbSeparator)
					raise ArgumentError, "'#{Doc::UserSourcedbSeparator}' is a special character reserved for separation of the username from a personal sourcedb name." unless parts.length == 2
					sourcedb, username = parts
					raise ArgumentError, "This document belongs to '#{username}'." unless username == current_user.username
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

	def self.delete_orphan_docs_of_user_sourcedb
		d_num = ActiveRecord::Base.connection.delete("DELETE FROM docs WHERE sourcedb LIKE '%#{Doc::UserSourcedbSeparator}%' AND NOT EXISTS (SELECT 1 FROM project_docs WHERE project_docs.doc_id = docs.id)")
	end

	def update_all_references_in_paragraphs = paragraphs.each { _1.update_references denotations }

	def update_all_references_in_sentences = sentences.each { _1.update_references denotations }

	private

	# default sort order
	#DefaultSort = [['sourceid', 'ASC']]
	def self.default_sort_order_for(project)
		return "sourceid ASC" if project&.small?

		''
	end


end
