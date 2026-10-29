class Doc < ActiveRecord::Base
	include Doc::AnnotationCounts
	include Doc::Import
	include Doc::Revision
	include Doc::Media
	include Doc::TextOperations
	include Doc::TextStructure
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

	def self.get_doc(docspec)
		if docspec[:sourcedb].present? && docspec[:sourceid].present?
			Doc.find_by_sourcedb_and_sourceid(docspec[:sourcedb], docspec[:sourceid])
		else
			nil
		end
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

	def self.delete_orphan_docs_of_user_sourcedb
		d_num = ActiveRecord::Base.connection.delete("DELETE FROM docs WHERE sourcedb LIKE '%#{Doc::UserSourcedbSeparator}%' AND NOT EXISTS (SELECT 1 FROM project_docs WHERE project_docs.doc_id = docs.id)")
	end
end
