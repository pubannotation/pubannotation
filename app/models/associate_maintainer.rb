class AssociateMaintainer < ActiveRecord::Base
	belongs_to :user
	belongs_to :project

	validates :user_id, :project_id, :presence => true
	
	def destroyable_for?(current_user)
		current_user.root? == true || (current_user == self.user || current_user == project.user)
	end
end
