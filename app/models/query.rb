class Query < ActiveRecord::Base
	belongs_to :organization, polymorphic: true

	# type
	# 0: project-independent, 1: project-dependent, 2: project-specific

	def editable?(current_user)
		current_user.present? && (current_user.root? || (organization.present? && current_user == organization.user))
	end

end
