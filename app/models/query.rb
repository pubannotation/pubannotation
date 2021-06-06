class Query < ActiveRecord::Base
	belongs_to :organization, polymorphic: true

	# type
	# 0: project-independent, 1: project-dependent, 2: project-specific
end
