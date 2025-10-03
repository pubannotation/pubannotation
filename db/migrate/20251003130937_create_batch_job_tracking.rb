class CreateBatchJobTracking < ActiveRecord::Migration[8.0]
  def change
    create_table :batch_job_trackings do |t|
      t.bigint :parent_job_id, null: false
      t.string :child_job_id
      t.string :status, default: 'pending', null: false
      t.json :doc_identifiers, null: false, default: []
      t.integer :item_count, null: false, default: 0
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps

      # Indexes for efficient querying
      t.index :parent_job_id, name: 'index_batch_tracking_on_parent_job'
      t.index :child_job_id, name: 'index_batch_tracking_on_child_job'
      t.index [:parent_job_id, :status], name: 'index_batch_tracking_on_parent_and_status'
      t.index :created_at, name: 'index_batch_tracking_on_created_at'
    end

    # Foreign key with cascade delete - when parent job is deleted, tracking records are too
    add_foreign_key :batch_job_trackings, :jobs, column: :parent_job_id, on_delete: :cascade
  end
end
