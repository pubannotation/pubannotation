class AddIndexToDocs < ActiveRecord::Migration
  def change
  	add_index :docs, :projects_count
  end
end
