class HomeController < ApplicationController
  def index
    @source_dbs = Doc.select(:sourcedb).source_dbs.uniq
    sort_order = sort_order(Project)
    @projects = Project.accessible(current_user).index
  end
end
