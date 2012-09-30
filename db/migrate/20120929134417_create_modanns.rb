class CreateModanns < ActiveRecord::Migration
  def change
    create_table :modanns do |t|
      t.string :hid
      t.string :modtype, :polymorphic => true
      t.references :modobj
      t.references :annset

      t.timestamps
    end
    add_index :modanns, :modobj_id
    add_index :modanns, :annset_id
  end
end
