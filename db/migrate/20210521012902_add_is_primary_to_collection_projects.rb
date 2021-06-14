class AddIsPrimaryToCollectionProjects < ActiveRecord::Migration[4.2]
  def change
    add_column :collection_projects, :is_primary, :boolean, default: false
  end
end
