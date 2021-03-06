class Relation < ActiveRecord::Base
	belongs_to :project
	belongs_to :subj, :polymorphic => true
	belongs_to :obj, :polymorphic => true

	has_many :modifications, :as => :obj, :dependent => :destroy

	validates :hid,     :presence => true
	validates :pred,    :presence => true
	validates :subj_id, :presence => true
	validates :obj_id,  :presence => true

	scope :in_project, -> (project_id) {
		where(project_id: project_id) unless project_id.nil?
	}

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
		
	after_save :increment_project_relations_num, :update_project_updated_at
	after_destroy :decrement_project_relations_num, :update_project_updated_at
	
	def span
		positions = (subj.span + obj.span).sort
		[positions.first, positions.last]
	end

	def as_json(options={})
		{
			id: hid,
			pred: pred,
			subj: subj.hid,
			obj: obj.hid
		}
	end

	# to be deprecated in favor of as_json
	def get_hash
		hrelation = Hash.new
		hrelation[:id]   = hid
		hrelation[:pred] = pred
		hrelation[:subj] = subj.hid
		hrelation[:obj]  = obj.hid
		hrelation
	end
	
	def self.project_relations_num(project_id, relations)
		relations.project_relations.count[project_id].to_i
	end
	
	def increment_project_relations_num
		Project.increment_counter(:relations_num, self.project.id)
	end

	def decrement_project_relations_num
		Project.decrement_counter(:relations_num, self.project.id)
	end

	def update_project_updated_at
		self.project.update_updated_at
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

	def self.new_id
		'R' + rand(99999).to_s
	end

end
