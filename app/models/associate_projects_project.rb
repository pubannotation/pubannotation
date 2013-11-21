class AssociateProjectsProject < ActiveRecord::Base
  belongs_to :project
  belongs_to :associate_project, :class_name => 'Project'
end
