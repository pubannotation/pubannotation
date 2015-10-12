class CreateAnnotators < ActiveRecord::Migration
  def change
    create_table :annotators do |t|
      t.string :abbrev
      t.string :name
      t.text :description
      t.string :home
      t.references :user
      t.string :url
      t.text :params
      t.integer :method
      t.string :url2
      t.text :params2
      t.integer :method2

      t.timestamps
    end
    add_index :annotators, :abbrev, :unique => true
    add_index :annotators, :user_id
  end
end
