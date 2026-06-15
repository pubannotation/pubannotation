class AddMediaSourceToDoc < ActiveRecord::Migration[8.1]
  def change
    add_column :docs, :media_sourcedb, :string
    add_column :docs, :media_sourceid, :string
    add_index :docs, [:media_sourcedb, :media_sourceid]
  end
end
