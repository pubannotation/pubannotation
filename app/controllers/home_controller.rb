class HomeController < ApplicationController
  def index
    @source_dbs = Doc.select(:sourcedb).source_dbs.uniq
    @projects = Project.unscoped.order_by(Project, params[:projects_order], current_user)
  end
end
