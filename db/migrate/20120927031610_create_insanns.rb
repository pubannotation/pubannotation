class CreateInsanns < ActiveRecord::Migration
  def change
    create_table :insanns do |t|
      t.string :hid
      #t.references :insobj, :polymorphic => true
      t.references :insobj
      t.string :instype
      t.references :annset

      t.timestamps
    end
    add_index :insanns, :insobj_id
    add_index :insanns, :annset_id
  end
end
