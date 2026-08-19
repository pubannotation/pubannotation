class MediaTranscript < ApplicationRecord
  belongs_to :medium
  belongs_to :doc

  validates :doc_id, uniqueness: true
  validate :medium_not_image
  validate :medium_matches_doc_medium

  private

  def medium_not_image
    errors.add(:medium, 'must not be an image') if medium&.image?
  end

  def medium_matches_doc_medium
    return unless medium && doc

    errors.add(:doc, 'must reference the same medium as this transcript') if doc.medium_id != medium_id
  end
end
