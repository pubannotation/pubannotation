class CreateQueries < ActiveRecord::Migration
  def change
    create_table :queries do |t|
      t.string :title, default: "", nul: false
      t.text :sparql, default: "", nul: false
      t.text :comment
      t.string :show_mode
      t.string :projects
      t.integer :priority, default: 0, null: false
      t.boolean :active, default: true, null: false
      t.references :project

      t.timestamps
    end
    add_index :queries, :project_id
  end
end
