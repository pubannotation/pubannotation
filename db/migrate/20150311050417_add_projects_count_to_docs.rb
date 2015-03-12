class AddProjectsCountToDocs < ActiveRecord::Migration
  def up 
    add_column :docs, :projects_count, :integer, default: 0
    Doc.all.each do |doc|
      doc.update_attribute(:projects_count, doc.projects.count)
    end
  end

  def down
    remove_column :docs, :projects_count
  end
end
