class MediaTranscript < ApplicationRecord
  belongs_to :medium
  belongs_to :doc

  validates :doc_id, uniqueness: true
end
