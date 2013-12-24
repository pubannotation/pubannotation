class AddPendingAssociateProjectsCountToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :pending_associate_projects_count, :integer, :default => 0
  end
end
