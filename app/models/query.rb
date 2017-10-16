class Query < ActiveRecord::Base
  belongs_to :project
  attr_accessible :active, :comment, :priority, :sparql, :title, :project_id, :show_mode, :projects
end
