class CreateRelanns < ActiveRecord::Migration
  def change
    create_table :relanns do |t|
      t.string :hid
      t.references :relsub, :polymorphic => true
      t.references :relobj, :polymorphic => true
      t.string :reltype
      t.references :annset

      t.timestamps
    end
    add_index :relanns, :relsub_id
    add_index :relanns, :relobj_id
    add_index :relanns, :annset_id
  end
end
