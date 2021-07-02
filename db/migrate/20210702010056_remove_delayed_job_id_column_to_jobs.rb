class RemoveDelayedJobIdColumnToJobs < ActiveRecord::Migration[5.2]
  def up
    remove_column :jobs, :delayed_job_id, :integer
  end

  def down
    add_column :jobs, :delayed_job_id, :integer
    add_index :jobs, :delayed_job_id
  end
end
