class HomeController < ApplicationController
  def index
    @sourcedbs = Doc.select(:sourcedb).sourcedbs.uniq
    sort_order = sort_order(Project)
    @projects_number = Project.accessible(current_user).length
    @projects_top = Project.accessible(current_user).top
  end
end
