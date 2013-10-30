class AssociateProjectsProject < ActiveRecord::Base
  belongs_to :project
  belongs_to :associate_project, :class_name => 'Project'
#   
  # validates_presence_of :project_id, :associate_project_id
  
  #before_destroy :decrement_counters
  
  # def decrement_counters
    # Sproject.update_counters self.sproject.id, 
      # :pmdocs_count => - self.project.pmdocs_count,
      # :pmcdocs_count => - self.project.pmcdocs_count,
      # :denotations_count => - self.project.denotations_count,
      # :relations_count => - self.project.relations_count
  # end
end
