class AddProgressAndMemoryFieldsToBatchJobTrackings < ActiveRecord::Migration[8.0]
  def change
    add_column :batch_job_trackings, :annotation_objects_count, :integer
    add_column :batch_job_trackings, :memory_estimation, :bigint
  end
end
