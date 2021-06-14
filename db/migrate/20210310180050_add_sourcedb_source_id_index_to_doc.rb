class AddSourcedbSourceIdIndexToDoc < ActiveRecord::Migration[4.2]
  def change
  	add_index :docs, [:sourcedb, :sourceid], unique: true
  end
end
