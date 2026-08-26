class MediaTranscriptionTask < ApplicationRecord
  belongs_to :medium
  belongs_to :job, optional: true

  enum :status, {
    pending: 'pending',
    processing: 'processing',
    succeeded: 'succeeded',
    no_speech: 'no_speech',
    failed: 'failed'
  }
end
