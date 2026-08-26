class CreateMediaTranscriptionTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :media_transcription_tasks do |t|
      t.references :medium, null: false, foreign_key: { on_delete: :cascade }
      t.references :job, null: true, foreign_key: { on_delete: :cascade }
      t.string :status, null: false, default: 'pending'

      t.timestamps
    end
  end
end
