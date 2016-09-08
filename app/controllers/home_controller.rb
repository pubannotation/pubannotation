class HomeController < ApplicationController
  def index
    @projects_number = Project.accessible(current_user).length
    @projects_top_annotations_count = Project.accessible(current_user).for_home.top_annotations_count
    @projects_top_recent = Project.accessible(current_user).for_home.top_recent
    @news_notifications = NewsNotification.limit(5) 
    @visit_logs = VisitLog.top(10)
  end
end
