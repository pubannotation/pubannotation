class CreateDocs < ActiveRecord::Migration
  def change
    create_table :docs do |t|
      t.text :body
      t.string :source
      t.string :sourcedb
      t.string :sourceid
      t.integer :serial
      t.string :section

      t.timestamps
    end
    add_index :docs, :sourceid
  end
end
