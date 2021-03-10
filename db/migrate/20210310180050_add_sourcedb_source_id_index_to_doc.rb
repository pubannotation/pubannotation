class AddSourcedbSourceIdIndexToDoc < ActiveRecord::Migration
  def change
  	add_index :docs, [:sourcedb, :sourceid], unique: true
  end
end
