class CreateJobs < ActiveRecord::Migration
  def change
    create_table :jobs do |t|
      t.references :project
      t.references :delayed_job
      t.integer :num_items
      t.integer :num_dones
      t.text :messages

      t.timestamps
    end
    add_index :jobs, :project_id
    add_index :jobs, :delayed_job_id
  end
end
