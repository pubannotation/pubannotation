class CreateMediaTranscripts < ActiveRecord::Migration[8.1]
  def change
    create_table :media_transcripts do |t|
      t.references :medium, null: false, foreign_key: { on_delete: :cascade }
      t.references :doc, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.json :segments, null: false, default: []

      t.timestamps
    end
  end
end
