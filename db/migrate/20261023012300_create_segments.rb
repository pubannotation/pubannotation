class CreateSegments < ActiveRecord::Migration[8.1]
  def change
    create_table :segments do |t|
      # The composite index below covers lookups by media_transcript_id alone.
      t.references :media_transcript, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer :position, null: false
      t.text :text, null: false
      t.integer :start_ms, null: false
      t.integer :end_ms, null: false
      t.boolean :line_break_after, null: false, default: false

      t.timestamps

      t.index %i[media_transcript_id position]
      t.check_constraint 'start_ms >= 0 AND end_ms >= start_ms', name: 'segments_times_in_order'
    end
  end
end
