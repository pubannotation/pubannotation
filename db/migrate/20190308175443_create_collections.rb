class CreateCollections < ActiveRecord::Migration
  def change
    create_table :collections do |t|
      t.string :name
      t.text :description
      t.string :reference
      t.references :user
      t.boolean :is_sharedtask, default: false
      t.integer :accessibility, default: 1

      t.timestamps
    end
  end
end
