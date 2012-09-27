class CreateAnnsets < ActiveRecord::Migration
  def change
    create_table :annsets do |t|
      t.string :name
      t.text :description
      t.string :annotator

      t.timestamps
    end
    add_index :annsets, :name, :unique => true
  end
end
