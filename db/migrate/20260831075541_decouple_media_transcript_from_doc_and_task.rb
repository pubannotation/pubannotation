class DecoupleMediaTranscriptFromDocAndTask < ActiveRecord::Migration[8.1]
  def up
    add_reference :media_transcripts, :medium, null: false, foreign_key: { on_delete: :cascade }

    remove_foreign_key :media_transcripts, :docs
    change_column_null :media_transcripts, :doc_id, true
    add_foreign_key :media_transcripts, :docs, on_delete: :nullify

    add_reference :media_transcripts, :media_transcription_task, null: true,
                  foreign_key: { on_delete: :nullify }, index: { unique: true }
  end

  def down
    remove_reference :media_transcripts, :media_transcription_task

    remove_foreign_key :media_transcripts, :docs
    change_column_null :media_transcripts, :doc_id, false
    add_foreign_key :media_transcripts, :docs, on_delete: :cascade

    remove_reference :media_transcripts, :medium
  end
end
