class Modification < ActiveRecord::Base
	include ProjectMemberConcern

	belongs_to :project
	belongs_to :obj, :polymorphic => true

	validates :hid, :presence => true
	validates :pred, :presence => true
	validates :obj, :presence => true

	after_save :increment_project_modifications_num, :update_project_updated_at
	after_destroy :decrement_project_modifications_num, :update_project_updated_at

	def span
		obj.span
	end

	def as_json(options={})
		{
			id: hid,
			pred: pred,
			obj: obj.hid
		}
	end

	# to be deprecated in favor of as_json
	def get_hash
		hmodification = Hash.new
		hmodification[:id] = hid
		hmodification[:pred] = pred
		hmodification[:obj] = obj.hid
		hmodification
	end

	scope :among_entities, -> (entity_ids) {
		case entity_ids
		when nil
			# all
		when []
			none
		else
			where("modifications.obj_id": entity_ids)
		end
	}

	def update_project_updated_at
		self.project.update_updated_at
	end

	def increment_project_modifications_num
		Project.increment_counter(:modifications_num, self.project.id)
	end

	def decrement_project_modifications_num
		Project.decrement_counter(:modifications_num, self.project.id)
	end

	def self.new_id_init(to_avoid = nil)
		@to_avoid = to_avoid
		@idnum = 0
	end

	def self.new_id
		loop do
			@idnum += 1
			_id = 'M' + @idnum.to_s
			break _id if !@to_avoid || !@to_avoid.include?(_id)
		end
	end
end
