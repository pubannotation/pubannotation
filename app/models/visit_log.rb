class VisitLog < ActiveRecord::Base
  attr_accessible :visited_date, :url
  belongs_to :project
  belongs_to :user

  scope :top, -> (limit) { 
    includes(:project).
    select('project_id, COUNT(*) AS count').
    group(:project_id).
    order('count DESC').
    limit(limit) 
  }

  scope :past_to_today, -> (days_ago) {
    where("visited_date > ?", days_ago.days.ago)
  }

  scope :by_visited_date, -> (days_ago) {
    past_to_today(days_ago).
    select('visited_date, COUNT(*) AS count').
    group('visited_date').
    order('visited_date ASC')
  }

  def self.log(arguments)
    project = Project.find_by_name(arguments[:project_name])
    if project && project.user != arguments[:user]
      visit_log = project.visit_logs.build(visited_date: Date.today, url: arguments[:url]) 
      visit_log.user = arguments[:user]
      visit_log.save
    end
  end
end
