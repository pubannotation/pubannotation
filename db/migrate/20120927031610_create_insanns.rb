class CreateInsanns < ActiveRecord::Migration
  def change
    create_table :insanns do |t|
      t.string :hid
      t.references :type, :polymorphic => true
      t.references :annset

      t.timestamps
    end
    add_index :insanns, :type_id
    add_index :insanns, :annset_id
  end
end
