class ProjectDoc < ActiveRecord::Base
	belongs_to :project
	belongs_to :doc

  attr_accessible :denotations_num, :relations_num, :modifications_num
end
