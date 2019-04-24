class CreateEvaluators < ActiveRecord::Migration
  def change
    create_table :evaluators do |t|
      t.string :name
      t.string :home
      t.text :description
      t.integer :access_type
      t.string :url
      t.references :user
      t.boolean :is_public, default: false

      t.timestamps
    end
    add_index :evaluators, :user_id
  end
end
