class CreateCatanns < ActiveRecord::Migration
  def change
    create_table :catanns do |t|
      t.string :hid
      t.references :doc
      t.integer :begin
      t.integer :end
      t.string :category
      t.references :annset

      t.timestamps
    end
    add_index :catanns, :doc_id
    add_index :catanns, :annset_id
  end
end
