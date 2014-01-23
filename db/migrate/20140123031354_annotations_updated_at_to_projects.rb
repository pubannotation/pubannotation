class AnnotationsUpdatedAtToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :annotations_updated_at, :datetime, :default => DateTime.now
  end
end
