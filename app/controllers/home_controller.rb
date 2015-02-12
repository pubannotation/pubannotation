class HomeController < ApplicationController
  def index
    @sourcedbs = Doc.select(:sourcedb).sourcedbs.uniq
    sort_order = sort_order(Project)
    @projects = Project.accessible(current_user).index
  end
end
