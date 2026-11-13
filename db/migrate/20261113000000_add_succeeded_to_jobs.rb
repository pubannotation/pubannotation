class AddSucceededToJobs < ActiveRecord::Migration[8.0]
  def change
    add_column :jobs, :succeeded, :boolean
  end
end
