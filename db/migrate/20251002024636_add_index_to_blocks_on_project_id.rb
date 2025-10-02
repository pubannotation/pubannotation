class AddIndexToBlocksOnProjectId < ActiveRecord::Migration[8.0]
  def change
    add_index :blocks, :project_id
  end
end
