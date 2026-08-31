class DecoupleMediaTranscriptFromDocAndTask < ActiveRecord::Migration[8.1]
  def up
    add_reference :media_transcripts, :medium, null: true, foreign_key: { on_delete: :cascade }

    # Backfill from the existing (currently required) doc_id before doc_id itself becomes
    # nullable below. Every row at this point has a doc_id, and every doc created from media
    # has a medium_id, so this covers all existing rows.
    execute <<~SQL.squish
      UPDATE media_transcripts
      SET medium_id = docs.medium_id
      FROM docs
      WHERE media_transcripts.doc_id = docs.id
    SQL

    orphaned_count = select_value('SELECT COUNT(*) FROM media_transcripts WHERE medium_id IS NULL').to_i
    if orphaned_count.positive?
      raise "Backfill failed: #{orphaned_count} media_transcripts row(s) still have a NULL medium_id " \
            '(their doc_id likely points to a doc with no medium). Resolve those rows before re-running this migration.'
    end

    change_column_null :media_transcripts, :medium_id, false

    remove_foreign_key :media_transcripts, :docs
    change_column_null :media_transcripts, :doc_id, true
    add_foreign_key :media_transcripts, :docs, on_delete: :nullify

    add_reference :media_transcripts, :media_transcription_task, null: true,
                  foreign_key: { on_delete: :nullify }, index: { unique: true }
  end

  def down
    remove_reference :media_transcripts, :media_transcription_task

    remove_foreign_key :media_transcripts, :docs

    null_doc_count = select_value('SELECT COUNT(*) FROM media_transcripts WHERE doc_id IS NULL').to_i
    if null_doc_count.positive?
      raise ActiveRecord::IrreversibleMigration,
            "Cannot revert: #{null_doc_count} media_transcripts row(s) have doc_id IS NULL " \
            '(e.g. a no-speech transcript that never had a Doc, or one whose doc was deleted). ' \
            'Resolve or remove those rows before reverting this migration.'
    end

    change_column_null :media_transcripts, :doc_id, false
    add_foreign_key :media_transcripts, :docs, on_delete: :cascade

    remove_reference :media_transcripts, :medium
  end
end
