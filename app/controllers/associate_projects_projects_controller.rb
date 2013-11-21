class AssociateProjectsProjectsController < ApplicationController
  def destroy
    associate_projects_project = AssociateProjectsProject.find_by_project_id_and_associate_project_id(params[:project_id], params[:associate_project_id], :joins => :project)
    #associate_projects_project.destroy
    associate_projects_project.project.associate_projects.delete(associate_projects_project.associate_project)
    flash[:notice] = t('controllers.shared.successfully_destroyed', :model => t('activerecord.models.associate_projects_project'))
    redirect_to :back
  end
end
