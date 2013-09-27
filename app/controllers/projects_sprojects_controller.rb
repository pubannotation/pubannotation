class ProjectsSprojectsController < ApplicationController
  def destroy
    projects_sproject = ProjectsSproject.find(params[:id])
    projects_sproject.destroy
    redirect_to :back
  end
end
