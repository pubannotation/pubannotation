class Attrivute < ActiveRecord::Base
	# The name of the class is changed to avoid conflict with the reserved word 'attribute'
	belongs_to :project
	belongs_to :subj, polymorphic: true

	attr_accessible :hid, :project_id, :subj, :obj, :pred

	validates :hid, presence: true
	validates :subj, presence: true
	validates :obj, presence: true
	validates :pred, presence: true

	after_save :update_project_updated_at
	after_destroy :update_project_updated_at

	def span
		subj.span
	end

	def as_json(options={})
		{
			id: hid,
			pred: pred,
			subj: subj.hid,
			obj: obj
		}
	end

	# to be deprecated in favor of as_json
	def get_hash
		{
			id:   hid,
			subj: subj.hid,
			obj:  obj,
			pred: pred
		}
	end

	scope :in_project, -> (project_id) {
		where(project_id: project_id) unless project_id.nil?
	}

	scope :among_entities, -> (entity_ids) {
		case entity_ids
		when nil
			# all
		when []
			none
		else
			where("attrivutes.subj_id": entity_ids)
		end
	}

	def update_project_updated_at
		self.project.update_updated_at
	end

	def self.new_id
		'A' + rand(99999).to_s
	end

end
