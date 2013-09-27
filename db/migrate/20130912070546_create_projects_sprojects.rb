class CreateProjectsSprojects < ActiveRecord::Migration
  def change
    create_table :projects_sprojects do |t|
      t.integer :project_id, :null => false
      t.integer :sproject_id, :null => false
    end
    
    add_index :projects_sprojects, :project_id
    add_index :projects_sprojects, :sproject_id
  end
end
