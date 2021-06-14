class CreateEditors < ActiveRecord::Migration[4.2]
  def change
    create_table :editors do |t|
      t.string :name
      t.string :url
      t.text :parameters
      t.text :description
      t.string :home
      t.references :user
      t.boolean :is_public, default: false

      t.timestamps
    end
    add_index :editors, :name, :unique => true
    add_index :editors, :user_id
  end
end
