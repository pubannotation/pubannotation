class CreateAnnotaionsProjects < ActiveRecord::Migration
  def change
    create_table :annotations_projects do |t|
      t.integer :annotation_id
      t.integer :project_id
    end
    add_index :annotations_projects, :annotation_id
    add_index :annotations_projects, :project_id
  end
end
