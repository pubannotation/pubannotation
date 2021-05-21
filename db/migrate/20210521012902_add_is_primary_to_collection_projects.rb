class AddIsPrimaryToCollectionProjects < ActiveRecord::Migration
  def change
    add_column :collection_projects, :is_primary, :boolean, default: false
  end
end
