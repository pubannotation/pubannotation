class CreateSequencers < ActiveRecord::Migration[4.2]
  def change
    create_table :sequencers do |t|
      t.string :name
      t.text :description
      t.string :home
      t.references :user
      t.string :url
      t.text :parameters

      t.timestamps
    end
    add_index :sequencers, :user_id
  end
end
