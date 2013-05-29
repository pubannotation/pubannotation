class CreateBlocks < ActiveRecord::Migration
  def change
    create_table :blocks do |t|
      t.string :hid
      t.references :doc
      t.integer :begin
      t.integer :end
      t.string :category
      t.references :project

      t.timestamps
    end
    add_index :blocks, :doc_id
    add_index :blocks, :project_id
  end
end
