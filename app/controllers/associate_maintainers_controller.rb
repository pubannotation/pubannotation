class AssociateMaintainersController < ApplicationController
	before_action :destroyable?, :only => :destroy
	
	def destroy
		if @associate_maintainer.destroy
			flash[:notice] = t('controllers.shared.successfully_destroyed', :model => t('activerecord.models.associate_maintainer'))
		end
		if @associate_maintainer.project.editable?(current_user)
			# when maintainer destroyed 
			redirect_to(edit_project_path(@associate_maintainer.project.name))  
		else
			# when associate maintainer destroyed self record
			# redirect to project#show because has no permission to edit project
			redirect_to(project_path(@associate_maintainer.project.name))  
		end
	end
	
	def destroyable?
		@associate_maintainer = AssociateMaintainer.find(params[:id])
		unless @associate_maintainer.destroyable_for?(current_user)
			render_status_error(:forbidden)
		end
	end
end
