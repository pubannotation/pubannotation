class AddQueueNameColumnToJobs < ActiveRecord::Migration[5.2]
  def change
    add_column :jobs, :queue_name, :string
  end
end
