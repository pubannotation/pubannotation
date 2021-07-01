class AddActiveJobIdColumnToJobs < ActiveRecord::Migration[5.2]
  def change
    add_column :jobs, :active_job_id, :string
  end
end
