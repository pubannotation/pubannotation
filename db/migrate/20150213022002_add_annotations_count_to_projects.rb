class AddAnnotationsCountToProjects < ActiveRecord::Migration
  def up 
    add_column :projects, :annotations_count, :integer, default: 0
    Project.all.each do |project|
      project.update_attribute(:annotations_count, project.denotations_count + project.relations_count + project.modifications.count)
    end
  end

  def down
    remove_column :projects, :annotations_count
  end
end
