class Relation < ActiveRecord::Base
	include DocMemberConcern
	include ProjectMemberConcern

	belongs_to :project
	belongs_to :doc
	belongs_to :subj, :polymorphic => true
	belongs_to :obj, :polymorphic => true

	has_many :attrivutes, :as => :subj, :dependent => :destroy

	validates :hid,     :presence => true
	validates :pred,    :presence => true
	validates :subj_id, :presence => true
	validates :obj_id,  :presence => true

	after_save :increment_numbers, :update_project_updated_at
	after_destroy :decrement_numbers, :update_project_updated_at
	after_update :update_project_updated_at

	def increment_numbers
		pd = ProjectDoc.find_by_project_id_and_doc_id(self.project.id, self.doc.id)
		pd.increment!(:relations_num) if pd
		self.doc.increment!(:relations_num)
		self.project.increment!(:relations_num)
	end

	def decrement_numbers
		pd = ProjectDoc.find_by_project_id_and_doc_id(self.project.id, self.doc.id)
		pd.decrement!(:relations_num) if pd
		self.doc.decrement!(:relations_num)
		self.project.decrement!(:relations_num)
	end

	def update_project_updated_at
		self.project.update_updated_at
	end

	scope :among_denotations, -> (denotation_ids) {
		case denotation_ids
		when nil
			# all
		when []
			none
		else
			where("relations.subj_id": denotation_ids, "relations.obj_id": denotation_ids)
		end
	}

	scope :project_relations, -> { select(:id).group("relations.project_id") }

	scope :project_pmcdoc_cat_relations, lambda{|sourceid|
		joins("INNER JOIN denotations ON relations.subj_id = denotations.id AND relations.subj_type = 'Denotation' INNER JOIN docs ON docs.id = denotations.doc_id AND docs.sourcedb = 'PMC'").
		where("docs.sourceid = ?", sourceid)
	}

	scope :projects_relations, lambda{|project_ids|
		where('project_id IN (?)', project_ids)
	}

	scope :accessible_projects, lambda{|current_user_id|
		joins(:project).
		where('projects.accessibility = 1 OR projects.user_id = ?', current_user_id)
	}

	scope :sql, lambda{|ids|
			where('relations.id IN(?)', ids).
			order('relations.id ASC') 
	}
		
	def span
		positions = subj.span + obj.span
		[positions.min, positions.max]
	end

	def in_span?(a_span)
		span.first >= a_span[:begin] && span.second <= a_span[:end]
	end

	def as_json(options={})
		{
			id: hid,
			pred: pred,
			subj: subj.hid,
			obj: obj.hid
		}
	end

	def <=>(other)
		(self.hid <=> other.hid)
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
					docs = self.accessible_projects(current_user_id).projects_relations([project.id]).sql(ids)
				else
					# within accessible projects
					docs = self.accessible_projects(current_user_id).sql(ids)
				end
			end     
		end     
	end

	def self.new_id_init(to_avoid = nil)
		@to_avoid = to_avoid
		@idnum = 0
	end

	def self.new_id
		loop do
			@idnum += 1
			_id = 'R' + @idnum.to_s
			break _id if !@to_avoid || !@to_avoid.include?(_id)
		end
	end
end
