class CreateAssociateProjectsProjects < ActiveRecord::Migration
  def change
    create_table :associate_projects_projects do |t|
      t.integer :project_id,            :null => false
      t.integer :associate_project_id,  :null => false
    end
    
    add_index :associate_projects_projects, :project_id
    add_index :associate_projects_projects, :associate_project_id    
  end
end
