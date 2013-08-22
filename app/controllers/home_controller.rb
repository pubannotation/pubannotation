class HomeController < ApplicationController
  def index
    @docs = Doc.where(:serial => 0)
    @pmdocs = Doc.where(:sourcedb => 'PubMed', :serial => 0)
    @pmcdocs = Doc.where(:sourcedb => 'PMC', :serial => 0)
    @user_projects = Project.order_by(current_user.projects, params[:projects_order], current_user)
    @associate_maintaiain_projects = Project.order_by(current_user.associate_maintaiain_projects, params[:projects_order], current_user)
    @projects = Project.order_by(Project, params[:projects_order], current_user)
  end
end
