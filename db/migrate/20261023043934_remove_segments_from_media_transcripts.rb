class RemoveSegmentsFromMediaTranscripts < ActiveRecord::Migration[8.1]
  # Moved to the segments table. Not copied over, as the media features are still being tried out.
  def change
    remove_column :media_transcripts, :segments, :json, null: false, default: []
  end
end
