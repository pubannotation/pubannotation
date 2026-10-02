class AddGenerationModelToMediaTranscripts < ActiveRecord::Migration[8.1]
  def change
    add_column :media_transcripts, :generation_model, :string
  end
end
