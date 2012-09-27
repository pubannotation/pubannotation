class CreateRelanns < ActiveRecord::Migration
  def change
    create_table :relanns do |t|
      t.string :hid
      t.references :subject, :polymorphic => true
      t.references :object, :polymorphic => true
      t.string :relation
      t.references :annset

      t.timestamps
    end
    add_index :relanns, :subject_id
    add_index :relanns, :object_id
    add_index :relanns, :annset_id
  end
end
