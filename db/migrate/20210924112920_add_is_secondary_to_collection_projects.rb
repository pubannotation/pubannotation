class AddIsSecondaryToCollectionProjects < ActiveRecord::Migration[5.2]
  def change
    add_column :collection_projects, :is_secondary, :boolean, default: false
  end
end
