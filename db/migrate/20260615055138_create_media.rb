class CreateMedia < ActiveRecord::Migration[8.1]
  def change
    create_table :media do |t|
      t.string  :sourcedb
      t.string  :sourceid
      t.integer :media_type
      t.string  :content_type

      t.timestamps
    end

    add_index :media, [:sourcedb, :sourceid], unique: true
  end
end
