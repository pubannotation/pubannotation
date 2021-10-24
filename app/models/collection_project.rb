class CollectionProject < ActiveRecord::Base
	belongs_to :collection
	belongs_to :project

	def self.is_primary?(collection, project)
		self.where(collection:collection, project:project).first.is_primary
	end

	def self.is_secondary?(collection, project)
		self.where(collection:collection, project:project).first.is_secondary
	end

	def toggle_primary
		update_attribute(:is_secondary, false) if is_secondary
		update_attribute(:is_primary, !is_primary)
	end

	def toggle_secondary
		update_attribute(:is_primary, false) if is_primary
		update_attribute(:is_secondary, !is_secondary)
	end
end
