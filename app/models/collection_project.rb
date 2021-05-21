class CollectionProject < ActiveRecord::Base
	belongs_to :collection
	belongs_to :project

	def toggle_primary
		update_attribute(:is_primary, !is_primary)
	end
end
