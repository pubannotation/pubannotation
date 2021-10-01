class CollectionProject < ActiveRecord::Base
	belongs_to :collection
	belongs_to :project

	def toggle_primary
		update_attribute(:is_secondary, false) if is_secondary
		update_attribute(:is_primary, !is_primary)
	end

	def toggle_secondary
		update_attribute(:is_primary, false) if is_primary
		update_attribute(:is_secondary, !is_secondary)
	end
end
