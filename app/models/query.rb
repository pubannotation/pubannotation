class Query < ActiveRecord::Base
  belongs_to :project
  attr_accessible :active, :comment, :priority, :sparql, :title, :project_id, :show_mode, :projects, :category

  # type
  # 0: project-independent, 1: project-dependent, 2: project-specific
end
