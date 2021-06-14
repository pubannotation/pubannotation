class CreateCollectionProjects < ActiveRecord::Migration[4.2]
  def change
    create_table :collection_projects do |t|
    	t.belongs_to :collection
    	t.belongs_to :project
      t.timestamps
    end
  end
end
