class CreateMessages < ActiveRecord::Migration
  def change
    create_table :messages do |t|
      t.string :body
      t.references :job

      t.timestamps
    end
    add_index :messages, :job_id
  end
end
