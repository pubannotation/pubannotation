class CollectionProject < ActiveRecord::Base
	belongs_to :collection
	belongs_to :project
end
